# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    import Pkg
    Pkg.activate(".")
    ARGS = ["--case=1_three_zones", "--run", "--profile"]
end

import GenX
import HiGHS
# solver
import JuMP
import HiGHS
# julia base
import SHA
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
    cases = readdir(joinpath(@__DIR__, "cases"); sort = false)
    valid_cases = filter(c -> isdir(joinpath(@__DIR__, "cases", c)), cases)
    print(
        """
        usage: julia --project=GenX GenX/main.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the directory in `GenX/cases` to run. Valid cases are
            * $(join(valid_cases, "\n    * "))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--write`  if provided, write out files to disk
         * `--profile` if provided, profile the case and write to `profile.jsonl`
        """,
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
        append!(cases, readdir(joinpath(@__DIR__, "cases"); join = true))
    else
        push!(cases, joinpath(@__DIR__, "cases", parsed_args["case"]))
    end
    for case in cases
        @info("Running $case")
        if get(parsed_args, "run", "false") == "true"
            model_name = "GenX_$(last(splitpath(case)))"
            HIGHS_WRITE_FILE_PREFIX[] = ""
            if write_files
                HIGHS_WRITE_FILE_PREFIX[] = model_name
            end
            try
                if get(parsed_args, "profile", "false") == "true"
                    # precompile run
                    GenX.run_genx_case!(case)
                    data = @proflist GenX.run_genx_case!(case) [
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
                    GenX.run_genx_case!(case)
                end
            catch e
                # this is necessary for case 6 given we set 500s o time limit
                println("Error running $case")
                @show e
            end
        end
    end
    return
end

main(ARGS)
