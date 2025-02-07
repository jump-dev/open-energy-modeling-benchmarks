# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    using Pkg
    Pkg.activate(".")
    ARGS = [
        "--case=1_electrolyzer_with_rolling_horizon.json",
        "--run",
        "--profile",
    ]
end

import SpineOpt
import SpineInterface
# solver
import JuMP
import HiGHS
# julia base
import SHA
# profile
import Profile
import FlameGraphs
import JSON

#python
import PyCall

# check python deps
try
    PyCall.pyimport("spinedb_api")
catch e
    println(
        """

ATTENTION!

--- SpineOpt intall issue ---

Error importing the SpineOpt python dependency: spinedb_api

Please make sure the python environment is correctly set up

You can install the dependencies by running the script:

$(joinpath(@__DIR__, "install_spinedb_api.jl"))

Before you re-run "main.jl" script you will need to restart the Julia session.

See the $(joinpath(@__DIR__, "README.md")) file for more information.

Note.
PyCall.pyprogramname: $(PyCall.pyprogramname)
pyimport("sys").executable: $(PyCall.pyimport("sys").executable)

---

Now we rethrow the default error message from PyCall:

""",
    )
    rethrow(e)
end

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
        usage: julia --project=SpineOpt SpineOpt/main.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the directory in `SpineOpt/cases` to run. Valid cases are
            * $(join(valid_cases, "\n    * "))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases
         * `--help`   print this help message
         * `--run`    if provided, execute the case with `SpineOpt.run_spineopt`
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
    for case in cases
        @info("Running $case")
        model_name = "SpineOpt_$(last(splitpath(case)))"
        HIGHS_WRITE_FILE_PREFIX[] = model_name
        if !write_files
            HIGHS_WRITE_FILE_PREFIX[] = ""
        end
        if get(parsed_args, "run", "false") == "true"
            try
                input_data = JSON.parsefile(case; use_mmap = false)
                db_url = "sqlite://"
                SpineInterface.close_connection(db_url)
                SpineInterface.open_connection(db_url)
                SpineInterface.import_data(db_url, input_data, "No comment")
                if get(parsed_args, "profile", "false") == "true"
                    # precompile run
                    SpineOpt.run_spineopt(
                        db_url,
                        nothing;
                        log_level = 3,
                        optimize = true,
                    )
                    data = @proflist SpineOpt.run_spineopt(
                        db_url,
                        nothing;
                        log_level = 3,
                        optimize = true,
                    ) [JuMP, HiGHS, :Highs_run]
                    @show data
                    save_proflist(
                        data;
                        output_filename = joinpath(
                            dirname(@__DIR__),
                            "profile.jsonl",
                        ),
                        label = model_name,
                    )
                else
                    SpineOpt.run_spineopt(
                        db_url,
                        nothing;
                        log_level = 3,
                        optimize = true,
                    )
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
