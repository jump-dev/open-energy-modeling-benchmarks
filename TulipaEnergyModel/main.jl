# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import TulipaEnergyModel as TEM
import DBInterface
import DuckDB
import TulipaIO as TIO
import HiGHS
import SHA

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
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--run`    if provided, execute the case with `TulipaEnergyModel.run_scenario`
         * `--write`  if provided, write out files to
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
    optimizer = HiGHS.Optimizer
    parameters = Dict(
        "output_flag" => true,
        "mip_rel_gap" => 1e-4,
        "time_limit" => 500.0,
    )
    for case in cases
        @info("Running $case")
        connection = DBInterface.connect(DuckDB.DB)
        TIO.read_csv_folder(
            connection,
            case;
            schemas = TEM.schema_per_table_name,
        )
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem; write_lp_file = false) # write_lp_file = true prints the LP file (model.lp) to the current directory
        # To get access to the JuMP model, use `energy_problem.model`
        if get(parsed_args, "run", "false") == "true"
            HIGHS_WRITE_FILE_PREFIX[] = "TulipaEnergyModel_$(last(splitpath(case)))"
            if !write_files
                HIGHS_WRITE_FILE_PREFIX[] = ""
            end
            try
                TEM.solve_model!(energy_problem, optimizer; parameters)
            catch e
                println("Error running $case")
                @show e
            end
        end
    end
    return
end

main(ARGS)
