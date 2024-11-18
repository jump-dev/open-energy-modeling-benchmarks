# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    using Pkg
    Pkg.activate(".")
    ARGS = ["--case=pglib_opf_case162_ieee_dtc.m", "--run", "--profile"]
end

import PowerModels
# solver
import JuMP
import HiGHS
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
    valid_cases = filter(c -> isfile(joinpath(@__DIR__, "cases", c)), cases)
    print(
        """
        usage: julia --project=PowerModels PowerModels/main.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the directory in `PowerModels/cases` to run. Valid cases are
            * $(join(valid_cases, "\n    * "))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--run`    if provided, execute the case with `PowerModels.solve_ots`
         * `--write`  if provided, write mps files
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
    list = [:solve_ots, JuMP, HiGHS, :Highs_run]
    if get(parsed_args, "profile", "false") == "true"
        profile_file_io = create_profile_file(list; named = "PowerModels Run")
    end
    for case in cases
        @info("Running $case")
        HIGHS_WRITE_FILE_PREFIX[] = "PowerModelsOTS_$(last(splitpath(case)))"
        if !write_files
            HIGHS_WRITE_FILE_PREFIX[] = ""
        end
        solver =
            JuMP.optimizer_with_attributes(HiGHS.Optimizer, "time_limit" => 0.0)
        if get(parsed_args, "run", "false") == "true"
            PowerModels.solve_ots(case, PowerModels.DCPPowerModel, solver)
            if get(parsed_args, "profile", "false") == "true"
                # precompile run
                PowerModels.solve_ots(case, PowerModels.DCPPowerModel, solver)
                Profile.clear()
                @profile PowerModels.solve_ots(
                    case,
                    PowerModels.DCPPowerModel,
                    solver,
                )
                write_profile_data(
                    profile_file_io,
                    get_profile_data(list);
                    named = "$(last(splitpath(case)))",
                )
            else
                PowerModels.solve_ots(case, PowerModels.DCPPowerModel, solver)
            end
        end
    end
    if get(parsed_args, "profile", "false") == "true"
        close_profile_file(profile_file_io)
    end
    return
end

main(ARGS)
