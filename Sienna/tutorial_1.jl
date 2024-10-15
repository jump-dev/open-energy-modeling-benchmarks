# # Extracted from:
# # https://nrel-sienna.github.io/PowerSimulations.jl/v0.28/tutorials/decision_problem/

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

const HIGHS_WRITE_FILE_PREFIX = Ref{String}("")

function _write_highs_model(highs)
    prefix = HIGHS_WRITE_FILE_PREFIX[]::String
    if isempty(prefix)
        error("Name needed")
        return
    end
    instances = joinpath(dirname(@__DIR__))
    # instances = joinpath(dirname(@__DIR__), "instances")
    tmp_filename = joinpath(instances, "tmp.mps")
    HiGHS.Highs_writeModel(highs, tmp_filename)
    # We SHA the raw file so that potential gzip differences across
    # platforms don't matter.
    hex = bytes2hex(open(SHA.sha256, tmp_filename))
    if false
        run(`gzip $tmp_filename`)
        mv(
            "$(tmp_filename).gz",
            joinpath(instances, "$prefix-$hex.mps.gz");
            force = true,
        )
    else
        mv(
            "$(tmp_filename)",
            joinpath(instances, "$prefix-$hex.mps");
            force = true,
        )
    end
    return
end

# !!! TYPE PIRACY TO INTERCEPT ALL HIGHS SOLVES AND WRITE THEM TO FILES !!!
function HiGHS.Highs_run(highs)
    _write_highs_model(highs)
    return ccall((:Highs_run, HiGHS.libhighs), Cint, (Ptr{Cvoid},), highs)
end

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

set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel))

net_models = Dict(
    "CopperPlate" => CopperPlatePowerModel,
    "PTDF" => PTDFPowerModel,
    "DC" => DCPPowerModel,
    "Transport" => NFAPowerModel,
)

# solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.0001) # hard
solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5) # easy

for (net_name, net_model) in net_models
    println("Solving $net_name")
    set_network_model!(template_uc, NetworkModel(net_model))
    for h in [1, 6, 12, 24, 48]

        @show H = Hour(h)
        # H = Hour(2 * 24)

        problem = DecisionModel(template_uc, sys; optimizer = solver, horizon = H, optimizer_solve_log_print = true)

        # build optimizes a model for initial conditions
        HIGHS_WRITE_FILE_PREFIX[] = "Sienna_modified_RTS_GMLC_DA_sys_initialization_Net$(net_name)_h$h"
        build!(problem, output_dir = mktempdir(), console_level = Logging.Info)

        HIGHS_WRITE_FILE_PREFIX[] = "Sienna_modified_RTS_GMLC_DA_sys_main_Net$(net_name)_h$h"
        solve!(problem, console_level = Logging.Info)
    end
end

# res = OptimizationProblemResults(problem)

# get_optimizer_stats(res)

# get_objective_value(res)

# read_variables(res)

# list_parameter_names(res)
# read_parameter(res, "ActivePowerTimeSeriesParameter__RenewableDispatch")