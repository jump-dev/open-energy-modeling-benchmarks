# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    using Pkg
    Pkg.activate(".")
    Pkg.add("FlameGraphs")
    Pkg.add("JSON")
    ARGS = ["--case=matpower/case14/2017-01-01", "--run", "--profile"]
end

import UnitCommitment
# solver
import JuMP
import HiGHS
# julia base
import Dates
import SHA
import Logging
# profile
import Profile
import FlameGraphs
import JSON

# helper functions
include("../utils/utils.jl")
include("../utils/profile.jl")
# !!! TYPE PIRACY TO INTERCEPT ALL HIGHS SOLVES AND WRITE THEM TO FILES !!!
include("../utils/highs_write.jl")

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

function build_and_solve(instance; time_limit = 600.0)
    model = UnitCommitment.build_model(;
        instance = instance,
        # optimizer = HiGHS.Optimizer,
        optimizer = JuMP.optimizer_with_attributes(
            HiGHS.Optimizer,
            "mip_rel_gap" => 0.01,
            "time_limit" => time_limit,
        ),
    )
    # iterative model, so we do no write files
    HIGHS_WRITE_FILE_PREFIX[] = ""
    UnitCommitment.optimize!(
        model,
        UnitCommitment.XavQiuWanThi2019.Method(; time_limit = time_limit),
    )
    return
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
            model_name = "UnitCommitment_$(replace(case, "/" => "_"))"
            try
                # Read benchmark instance
                instance = UnitCommitment.read_benchmark(case)
                if get(parsed_args, "profile", "false") == "true"
                    build_and_solve(instance; time_limit = 10.01)
                    data =
                        @proflist build_and_solve(instance; time_limit = 10.01) [
                            JuMP,
                            HiGHS,
                            :Highs_run,
                        ]
                    save_proflist(
                        data;
                        output_filename = joinpath(
                            dirname(@__DIR__),
                            "profile.jsonl",
                        ),
                        label = model_name,
                    )
                else
                    build_and_solve(instance; time_limit = 600.0)
                end
                # we only write files for the last model
                if write_files
                    HIGHS_WRITE_FILE_PREFIX[] = model_name
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
