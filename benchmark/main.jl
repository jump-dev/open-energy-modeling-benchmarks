# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import DataFrames
import HiGHS
import JSON
import Statistics

const INSTANCE_DIR = joinpath(dirname(@__DIR__), "instances")

_is_mps(c) = endswith(c, ".mps.gz")

function print_help()
    files = readdir(INSTANCE_DIR; sort = false)
    print(
        """
        usage: julia --project=benchmark benchmark/main.jl \
            --instance=<name> | --all | --analyze
            [--help]
            [--output_filename=<output.jsonl>]
            [--option=<value>]

        ## Arguments

         * `--instance`:  the file in `instance` to run. Valid files are
            * $(join(filter(_is_mps, files), "\n    * "))
         * `--all`        if passed, `--instance` must not be passed, and the
                          argument will loop over all valid instances
         * `--analyze`    if passed, run the analysis script
         * `--help`       print this help message
         * `--output_filename`  the file in which to store solution logs
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
    result = Dict(
        "filename" => filename,
        "options" => parsed_args,
        "version" => "v$X.$Y.$Z",
        "julia_total_time" => total_time,
        "highs_run_time" => HiGHS.Highs_getRunTime(highs),
        "highs_objective_value" => HiGHS.Highs_getObjectiveValue(highs),
        "run_status" => run_status,
        "model_status" => HiGHS.Highs_getModelStatus(highs),
    )
    pBool = Ref{Cint}(0)
    HiGHS.Highs_getIntInfoValue(highs, "valid", pBool)
    if pBool[] == 0
        return result
    end
    # INFO
    pType = Ref{Cint}()
    for info in [
        "simplex_iteration_count",
        "ipm_iteration_count",
        "crossover_iteration_count",
        "primal_solution_status",
        "dual_solution_status",
        "basis_validity",
        "num_primal_infeasibilities",
        "num_dual_infeasibilities",
        "objective_function_value",
        "mip_dual_bound",
        "mip_gap",
        "max_integrality_violation",
        "max_primal_infeasibility",
        "sum_primal_infeasibilities",
        "max_dual_infeasibility",
        "sum_dual_infeasibilities",
    ]
        Highs_getInfoType(highs, info, pType)
        if pType[] == HiGHS.kHighsInfoTypeInt
            pInt = Ref{Cint}()
            HiGHS.Highs_getIntInfoValue(highs, info, pInt)
            result[info] = pInt[]
        elseif pType[] == HiGHS.kHighsInfoTypeDouble
            pDouble = Ref{Cdouble}()
            HiGHS.Highs_getDoubleInfoValue(highs, info, pDouble)
            result[info] = pDouble[]
        end
    end
    return result
end

sgm(x::Vector{BigFloat}; sh::BigFloat) = exp(sum(log(max(1, xi + sh)) for xi in x) / length(x)) - sh
sgm(x; sh = 10.0) = round(Float64(sgm(BigFloat.(x); sh = big(sh))); digits = 2)

function geometric_mean(df, key)
    return DataFrames.combine(
        DataFrames.groupby(
            DataFrames.combine(
                DataFrames.groupby(df, [:filename, :solver_version]),
                key => Statistics.mean => key,
            ),
            [:solver_version]
        ),
        key => sgm => key,
    )
end

function analyse_output(output_filename = "output.jsonl")
    df = DataFrames.DataFrame(JSON.parse.(readlines(output_filename)))
    df.solver = get.(df.options, "solver", "default")
    df.solver_version = string.(df.version, "-", df.solver)
    df.uuid = String.(first.(split.(last.(split.(df.filename, '/')), '-')))
    result = geometric_mean(df, :julia_total_time)
    @info "SGM(sh=10) for :julia_total_time"
    display(result)
    function get_wide(df, key)
        df_long = df[:, [:uuid, :solver_version, key]]
        return DataFrames.unstack(df_long, :uuid, :solver_version, key)
    end
    for key in (:run_status, :model_status, :highs_objective_value)
        @info key
        display(get_wide(df, key))
    end
    return
end

function main(args)
    parsed_args = _parse_args(args)
    output_filename = get(parsed_args, "output_filename", "output.jsonl")
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    elseif get(parsed_args, "analyze", "false") == "true"
        return analyse_output(output_filename)
    end
    instances = String[]
    if get(parsed_args, "all", "false") == "true"
        append!(instances, filter(_is_mps, readdir(INSTANCE_DIR; join = true)))
    else
        push!(instances, joinpath(INSTANCE_DIR, parsed_args["instance"]))
    end
    for instance in instances
        ret = benchmark(instance, parsed_args)
        open(output_filename, "a") do io
            return println(io, JSON.json(ret))
        end
    end
    return
end

main(ARGS)
