# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    using Pkg
    Pkg.activate(".")
    # ARGS = ["--all", "--run", "--write"]
    ARGS = ["--case=matpower/case14/2017-01-01", "--run", "--profile"]
end

import HiGHS
import JuMP
import UnitCommitment
import SHA
import Dates

function print_help()
    valid_cases = uc_cases()
    print(
        """
        usage: julia --project=UnitCommitment UnitCommitment/main.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the directory in `UnitCommitment/cases` to run. Valid cases are
            * $(join(valid_cases, "\n    * "))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--run`    if provided, execute the case with `UnitCommitment.`
         * `--write`  if provided, write mps files
        """,
    )
    return
end

function _parse_args(args)
    ret = Dict{String,String}()
    for arg in args
        if (m = match(r"--([a-z]+)=(.+?)($|\s)", arg)) !== nothing
            ret[m[1]] = m[2]
        elseif (m = match(r"--([a-z]+?)($|\s)", arg)) !== nothing
            ret[m[1]] = "true"
        else
            error("unsupported argument $arg")
        end
    end
    return ret
end

const HIGHS_WRITE_FILE_PREFIX = Ref{String}("UNNAMED")

function _write_highs_model(highs)
    prefix = HIGHS_WRITE_FILE_PREFIX[]::String
    if isempty(prefix)
        return
    end
    instances = joinpath(dirname(@__DIR__), "instances")
    tmp_filename = joinpath(instances, "tmp.mps")
    HiGHS.Highs_writeModel(highs, tmp_filename)
    # We SHA the raw file so that potential gzip differences across
    # platforms don't matter.
    hex = bytes2hex(open(SHA.sha256, tmp_filename))
    run(`gzip $tmp_filename`)
    mv(
        "$(tmp_filename).gz",
        joinpath(instances, "$prefix-$hex.mps.gz");
        force = true,
    )
    return
end

# !!! TYPE PIRACY TO INTERCEPT ALL HIGHS SOLVES AND WRITE THEM TO FILES !!!
function HiGHS.Highs_run(highs)
    _write_highs_model(highs)
    return ccall((:Highs_run, HiGHS.libhighs), Cint, (Ptr{Cvoid},), highs)
end

function uc_cases()
    return [
        "pglib-uc/ferc/2015-01-01_hw",
        "pglib-uc/ferc/2015-01-01_lw",
        "pglib-uc/ca/2014-09-01_reserves_0",
        "pglib-uc/rts_gmlc/2020-01-27",
        "matpower/case1888rte/2017-01-01",
        "matpower/case1951rte/2017-01-01",
        "matpower/case2848rte/2017-01-01",
        "matpower/case3012wp/2017-01-01",
        "matpower/case6468rte/2017-01-01",
        "matpower/case6470rte/2017-01-01",
    ]
end

function main(args)
    parsed_args = _parse_args(args)
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    end
    write_files = get(parsed_args, "write", "false") == "true"
    cases = String[]
    if get(parsed_args, "all", "false") == "true"
        append!(cases, uc_cases())
    else
        push!(cases, parsed_args["case"])
    end
    for case in cases
        @info("Running $case")
        if get(parsed_args, "run", "false") == "true"
            try
                # Read benchmark instance
                instance = UnitCommitment.read_benchmark(case)
                # Construct model (using state-of-the-art defaults)
                model = UnitCommitment.build_model(;
                    instance = instance,
                    # optimizer = HiGHS.Optimizer,
                    optimizer = JuMP.optimizer_with_attributes(
                        HiGHS.Optimizer,
                        "mip_rel_gap" => 0.01,
                        "time_limit" => 600.0,
                    ),
                )
                # iterative model, so we do no write files
                HIGHS_WRITE_FILE_PREFIX[] = ""
                UnitCommitment.optimize!(
                    model,
                    UnitCommitment.XavQiuWanThi2019.Method(;
                        time_limit = 600.0,
                    ),
                )
                # we only write files for the last model
                if write_files
                    HIGHS_WRITE_FILE_PREFIX[] = "UnitCommitment_$(replace(case, "/" => "_"))"
                    JuMP.set_time_limit_sec(model, 0.0)
                    JuMP.optimize!(model)
                end
            catch e
                println("Error running $case")
                @show e
            end
        end
    end
    return
end

main(ARGS)
