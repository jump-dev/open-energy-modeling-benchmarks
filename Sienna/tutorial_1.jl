# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# necessary sienna stack
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
# solver
using HiGHS
# julia base
using Dates
using SHA
using Logging

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
         * `--write`  if provided, write out files to
        """
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

#=
    HiGHS overloads to print models to files
=#

const HIGHS_WRITE_FILE_PREFIX = Ref{String}("")

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

# selected from:
# https://github.com/jump-dev/open-energy-modeling-benchmarks/pull/20#issuecomment-2426998081
days_options() = sort([332, 29, 314])

horizon_options() = [12, 24, 48]

network_options() = [
    "CopperPlate",
    "PTDF",
    "DC",
    "Transport",
]

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

    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)

    set_service_model!(template_uc, VariableReserve{ReserveUp}, RangeReserve)
    set_service_model!(template_uc, VariableReserve{ReserveDown}, RangeReserve)

    # hard to solve configuration (0.01% gap)
    # solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.0001)
    # easy configuration so that it is easy to print (50% gap)
    solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)

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
            elseif haskey(parsed_args, "case") && "$(net_name)-$(h)-$(day)" != parsed_args["case"]
                continue
            else
                @info("No case selected")
                return
            end

            @info("Running $net_name with $h hours for day $day")

            if get(parsed_args, "run", "false") != "true"
                continue
            end

            problem = DecisionModel(
                template_uc,
                sys;
                optimizer = solver,
                horizon = Hour(h),
                initial_time = DateTime("2020-01-01T00:00:00") + Hour((day - 1) * 24),
                optimizer_solve_log_print = true,
            )

            # this build step also optimizes a model for initial conditions
            # we skip this print step
            HIGHS_WRITE_FILE_PREFIX[] = ""
            build!(problem, output_dir = mktempdir(), console_level = Logging.Info)

            # the solve step optimizes the main model
            HIGHS_WRITE_FILE_PREFIX[] = "Sienna_modified_RTS_GMLC_DA_sys_Net$(net_name)_Horizon$(h)_Day$day"
            if !write_files
                HIGHS_WRITE_FILE_PREFIX[] = ""
            end
            solve!(problem, console_level = Logging.Info)
        end
    end
    return
end

main(ARGS)
