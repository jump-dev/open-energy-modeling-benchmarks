# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

if isinteractive()
    cd(@__DIR__)
    import Pkg
    Pkg.activate(".")
    ARGS = ["--case=CopperPlate-12-29", "--run", "--profile"]
end

# necessary sienna stack
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
# solver
using JuMP
using HiGHS
# julia base
using Dates
using SHA
using Logging
# profile
import Profile
import FlameGraphs
import JSON

# helper functions
include("../utils/utils.jl")
include("../utils/profile.jl")
# !!! TYPE PIRACY TO INTERCEPT ALL HIGHS SOLVES AND WRITE THEM TO FILES !!!
include("../utils/highs_write.jl")

#=
    Command line argument parsing
=#

function print_help()
    print(
        """
        usage: julia --project=Sienna Sienna/tutorial_1.jl \
            --case=<case> | --all \
            [--help]      \
            [--run]       \
            [--write]     \

        ## Arguments

         * `--case`:  the option of network and horizon to run. Valid cases are
            * $(join(vec(["$(net)-<hor>-<day>" for net in network_options()]), "\n    * "))
            For <hor> in 1 to 48 (suggested horizons are $(join(horizon_options(), ", ")))
            For <day> in 1 to 365 (suggested days are $(join(days_options(), ", ")))
         * `--all`    if passed, `--case` must not be passed, and the argument
                      will loop over all valid cases only for the above suggested
                      days and horizons.
         * `--help`   print this help message
         * `--run`    if provided, execute the case
         * `--write`  if provided, write out files to disk
         * `--profile` if provided, profile the case and write to `profile.jsonl`
        """,
    )
    return
end

# selected from:
# https://github.com/jump-dev/open-energy-modeling-benchmarks/pull/20#issuecomment-2426998081
days_options() = sort([332, 29, 314])

horizon_options() = [12, 24, 48]

network_options() = ["CopperPlate", "PTDF", "DC", "Transport"]

function build_and_solve(problem)
    file_name = HIGHS_WRITE_FILE_PREFIX[]
    # skip the first file print
    HIGHS_WRITE_FILE_PREFIX[] = ""
    build!(problem; output_dir = mktempdir(), console_level = Logging.Info)
    # write the file
    HIGHS_WRITE_FILE_PREFIX[] = file_name
    solve!(problem; console_level = Logging.Info)
    return
end

#=
    Main Sienna loop to optimize a decision model
=#

function main(args)
    parsed_args = _parse_args(args)
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    end
    write_files = get(parsed_args, "write", "false") == "true"

    # case data is downloaded from a julia artifcat
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

    template_uc = ProblemTemplate()

    set_device_model!(template_uc, Line, StaticBranch)
    set_device_model!(template_uc, Transformer2W, StaticBranch)
    set_device_model!(template_uc, TapTransformer, StaticBranch)

    set_device_model!(
        template_uc,
        ThermalStandard,
        ThermalStandardUnitCommitment,
    )
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)

    set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
    set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

    # hard to solve configuration (0.01% gap)
    # solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.0001)
    # easy configuration so that it is easy to print (50% gap)
    solver = optimizer_with_attributes(
        HiGHS.Optimizer,
        "mip_rel_gap" => 0.5,
        # "time_limit" => 0.1,
    )

    net_models = Dict(
        "CopperPlate" => CopperPlatePowerModel,
        "PTDF" => PTDFPowerModel,
        "DC" => DCPPowerModel,
        "Transport" => NFAPowerModel,
    )

    parsed_args_all = get(parsed_args, "all", "false")

    for net_name in network_options()
        set_network_model!(template_uc, NetworkModel(net_models[net_name]))
        for h in 1:48, day in 1:365
            if parsed_args_all == "true"
                if day in days_options() && h in horizon_options()
                    # proceed normally
                else
                    continue # because there are way too many options
                end
            elseif haskey(parsed_args, "case") &&
                   "$(net_name)-$(h)-$(day)" != parsed_args["case"]
                continue
            end

            @info("Running $net_name with $h hours for day $day")

            if get(parsed_args, "run", "false") != "true"
                continue
            end

            model_name = "Sienna_modified_RTS_GMLC_DA_sys_Net$(net_name)_Horizon$(h)_Day$day"

            HIGHS_WRITE_FILE_PREFIX[] = ""
            if write_files
                HIGHS_WRITE_FILE_PREFIX[] = model_name
            end

            problem = DecisionModel(
                template_uc,
                sys;
                optimizer = solver,
                horizon = Hour(h),
                initial_time = DateTime("2020-01-01T00:00:00") +
                               Hour((day - 1) * 24),
                optimizer_solve_log_print = true,
            )

            if get(parsed_args, "profile", "false") == "true"
                # precompile run
                build_and_solve(problem)
                data =
                    @proflist build_and_solve(problem) [JuMP, HiGHS, :Highs_run]
                save_proflist(
                    data;
                    output_filename = joinpath(
                        dirname(@__DIR__),
                        "profile.jsonl",
                    ),
                    label = model_name,
                )
            else
                build_and_solve(problem)
            end
        end
    end

    return
end

main(ARGS)
