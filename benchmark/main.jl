# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import HiGHS
import JSON

const INSTANCE_DIR = joinpath(dirname(@__DIR__), "instances")

_is_mps(c) = endswith(c, ".mps.gz")

function print_help()
    files = readdir(INSTANCE_DIR; sort = false)
    print(
        """
        usage: julia --project=benchmark benchmark/main.jl \
            --instance=<name> | --all
            [--help]
            [--output_file=<data_time.jsonl>]
            [--option=<value>]

        ## Arguments

         * `--instance`:  the file in `instance` to run. Valid files are
            * $(join(filter(_is_mps, files), "\n    * "))
         * `--all`    if passed, `--instance` must not be passed, and the
                      argument will loop over all valid instances
         * `--help`   print this help message
         * `--option=<value>`   option value pairs that are passed directly to
                                HiGHS
        """
    )
    return
end

function _parse_args(args)
    ret = Dict{String,String}()
    for arg in args
        @assert startswith(arg, "--")
        arg = arg[3:end]
        if occursin("=", arg)
            items = split(arg, "=")
            @assert length(items) == 2
            ret[items[1]] = items[2]
        else
            ret[arg] = "true"
        end
    end
    return ret
end

function benchmark(filename, parsed_args)
    start_time = time()
    highs = HiGHS.Highs_create()
    ret = HiGHS.Highs_readModel(highs, filename)
    @assert ret == 0
    typeP = Ref{Cint}()
    for (option, value) in parsed_args
        if option in ("instance", "all", "help")
            continue
        end
        ret = HiGHS.Highs_getOptionType(highs, option, typeP)
        if !iszero(ret)
            # Not an option. Skip.
        elseif typeP[] == HiGHS.kHighsOptionTypeBool
            HiGHS.Highs_setBoolOptionValue(highs, option, parse(Cint, value))
        elseif typeP[] == HiGHS.kHighsOptionTypeInt
            HiGHS.Highs_setIntOptionValue(highs, option, parse(Cint, value))
        elseif typeP[] == HiGHS.kHighsOptionTypeDouble
            HiGHS.Highs_setDoubleOptionValue(highs, option, parse(Float64, value))
        else
            @assert typeP[] == HiGHS.kHighsOptionTypeString
            HiGHS.Highs_setStringOptionValue(highs, option, value)
        end
    end
    run_status = HiGHS.Highs_run(highs)
    total_time = time() - start_time
    X = HiGHS.Highs_versionMajor()
    Y = HiGHS.Highs_versionMinor()
    Z = HiGHS.Highs_versionPatch()
    return Dict(
        "version" => "v$X.$Y.$Z",
        "julia_total_time" => total_time,
        "highs_run_time" => HiGHS.Highs_getRunTime(model),
        "highs_objective_value" => HiGHS.Highs_getObjectiveValue(model),
        "run_status" => run_status,
        "model_status" => HiGHS.Highs_getModelStatus(model),
    )
end

function main(args)
    parsed_args = _parse_args(args)
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    end
    instances = String[]
    if get(parsed_args, "all", "false") == "true"
        append!(instances, filter(_is_mps, readdir(INSTANCE_DIR; join = true)))
    else
        push!(instances, joinpath(INSTANCE_DIR, parsed_args["instance"]))
    end
    for instance in instances
        ret = benchmark(instance, parsed_args)
        open("output.jsonl") do io
            return println(io, JSON.json(ret))
        end
    end
    return
end

# julia --project=benchmark benchmark/main.jl --instance=09d8dfdaa3dff578cb9f3af8ecefe9dab893a0ada31310c6b4010972415e8b44-GenX_8_three_zones_w_colocated_VRE_storage_electrolyzers.mps.gz --solver=ipm
main(ARGS)
