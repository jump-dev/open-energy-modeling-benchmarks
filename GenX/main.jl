# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    using Pkg
    Pkg.activate(".")
    ARGS = ["--case=1_three_zones", "--run", "--profile"]
end

import GenX
import HiGHS
# solver
using JuMP
using HiGHS
# julia base
import SHA
# profile
using Profile
using FlameGraphs

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
         * `--run`    if provided, execute the case with `GenX.run_genx_case!`
         * `--write`  if provided, write out files to
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
    list = [:run_genx_case!, JuMP, HiGHS, :Highs_run]
    if get(parsed_args, "profile", "false") == "true"
        profile_file_io = create_profile_file(list; named = "Sienna Run")
    end
    for case in cases
        @info("Running $case")
        if get(parsed_args, "run", "false") == "true"
            HIGHS_WRITE_FILE_PREFIX[] = ""
            if write_files
                HIGHS_WRITE_FILE_PREFIX[] = "GenX_$(last(splitpath(case)))"
            end
            try
                if get(parsed_args, "profile", "false") == "true"
                    # precompile run
                    GenX.run_genx_case!(case)
                    Profile.clear()
                    @profile GenX.run_genx_case!(case)
                    write_profile_data(
                        profile_file_io,
                        get_profile_data(list);
                        named = "$(last(splitpath(case)))",
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
    if get(parsed_args, "profile", "false") == "true"
        close_profile_file(profile_file_io)
    end
    return
end

main(ARGS)
