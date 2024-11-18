# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

cd(@__DIR__)
using Pkg
Pkg.activate(".")
ARGS = ["--case=1_EU_investment_simple-24", "--run", "--profile"]

# tulipa required stack
import TulipaEnergyModel as TEM
import DBInterface
import DuckDB
import TulipaIO as TIO
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
        usage: julia --project=TulipaEnergyModel TulipaEnergyModel/main.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the directory in `TulipaEnergyModel/cases` to run. Valid cases are
            * $(join(valid_cases, "\n    * "))
            * $(join(vec(["$(case)-<ts>" for net in valid_cases]), "\n    * "))
            For <ts> in 1 to 8760 (suggested horizons are $(join(timestep_options(), ", ")))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--run`    if provided, execute the case with `TulipaEnergyModel.run_scenario`
         * `--write`  if provided, write out files to
        """,
    )
    return
end

timestep_options() = [24, 168, 672, 2016, 4032, 8760]

function build_and_solve(connection)
    optimizer = HiGHS.Optimizer
    parameters =
        Dict("output_flag" => true, "mip_rel_gap" => 50.0, "time_limit" => 1.0)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)
    TEM.solve_model!(energy_problem, optimizer; parameters)
    return
end

function main(args)
    parsed_args = _parse_args(args)
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    end
    write_files = get(parsed_args, "write", "false") == "true"
    cases = Tuple{String,Int}[]
    if get(parsed_args, "all", "false") == "true"
        case_names = readdir(joinpath(@__DIR__, "cases"); join = true)
        timesteps = timestep_options()
        for case in case_names
            for timestep in timesteps
                push!(cases, (case, timestep))
            end
        end
    else
        case, timestep = split(get(parsed_args, "case", ""), "-")
        push!(cases, (joinpath(@__DIR__, "cases", case), parse(Int, timestep)))
    end

    list = [:build_and_solve, JuMP, HiGHS, :Highs_run]

    if get(parsed_args, "profile", "false") == "true"
        profile_file_io = create_profile_file(list; named = "Tulipa Run")
    end

    for (case, timestep) in cases
        @info("Running $case for $timestep timesteps")
        connection = DBInterface.connect(DuckDB.DB)
        TIO.read_csv_folder(
            connection,
            case;
            schemas = TEM.schema_per_table_name,
        )
        DuckDB.query(
            connection,
            "UPDATE rep_periods_data SET num_timesteps = $timestep WHERE year = 2030 AND rep_period = 1",
        )
        # To get access to the JuMP model, use `energy_problem.model`
        if get(parsed_args, "run", "false") == "true"
            HIGHS_WRITE_FILE_PREFIX[] = "TulipaEnergyModel_$(last(splitpath(case)))_$(timestep)h"
            if !write_files
                HIGHS_WRITE_FILE_PREFIX[] = ""
            end
            try
                if get(parsed_args, "profile", "false") == "true"
                    # precompile run
                    build_and_solve(connection)
                    Profile.clear()
                    @profile build_and_solve(connection)
                    write_profile_data(
                        profile_file_io,
                        get_profile_data(list);
                        named = "$(last(splitpath(case)))_$(timestep)h",
                    )
                else
                    build_and_solve(connection)
                end
            catch e
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
