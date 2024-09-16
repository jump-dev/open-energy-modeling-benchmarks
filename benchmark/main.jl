# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import DataFrames
import HiGHS_jll: libhighs
import JSON
import Statistics

const INSTANCE_DIR = joinpath(dirname(@__DIR__), "instances")

_is_mps(c) = endswith(c, ".mps.gz")

function print_help()
    files = readdir(INSTANCE_DIR; sort = false)
    print(
        """
        usage: julia --project=benchmark benchmark/main.jl \
            --instance=<name> | --all | --analyze
            [--help]
            [--output_filename=<output.jsonl>]
            [--option=<value>]

        ## Arguments

         * `--instance`:  the file in `instance` to run. Valid files are
            * $(join(filter(_is_mps, files), "\n    * "))
         * `--all`        if passed, `--instance` must not be passed, and the
                          argument will loop over all valid instances
         * `--analyze`    if passed, run the analysis script
         * `--help`       print this help message
         * `--output_filename`  the file in which to store solution logs
         * `--option=<value>`   option value pairs that are passed directly to
                                HiGHS
        """
    )
    return
end

function _parse_args(args)
    ret = Dict{String,String}()
    for arg in args
        @assert startswith(arg, "--")
        arg = arg[3:end]
        if occursin("=", arg)
            items = split(arg, "=")
            @assert length(items) == 2
            ret[items[1]] = items[2]
        else
            ret[arg] = "true"
        end
    end
    return ret
end

function benchmark(filename, parsed_args)
    start_time = time()
    highs = @ccall libhighs.Highs_create()::Ptr{Cvoid}
    ret = @ccall libhighs.Highs_readModel(
        highs::Ptr{Cvoid},
        filename::Ptr{Cchar},
    )::Cint
    @assert ret == 0
    typeP = Ref{Cint}()
    for (option, value) in parsed_args
        if option in ("instance", "all", "help")
            continue
        end
        ret = @ccall libhighs.Highs_getOptionType(
            highs::Ptr{Cvoid},
            option::Ptr{Cchar},
            typeP::Ptr{Cint},
        )::Cint
        if !iszero(ret)
            # Not an option. Skip.
        elseif typeP[] == Cint(0)  # kHighsOptionTypeBool
            @ccall libhighs.Highs_setBoolOptionValue(
                highs::Ptr{Cvoid},
                option::Ptr{Cchar},
                parse(Cint, value)::Cint,
            )::Cint
        elseif typeP[] == Cint(1)  # kHighsOptionTypeInt
            @ccall libhighs.Highs_setIntOptionValue(
                highs::Ptr{Cvoid},
                option::Ptr{Cchar},
                parse(Cint, value)::Cint,
            )::Cint
        elseif typeP[] == Cint(2)  # kHighsOptionTypeDouble
            @ccall libhighs.Highs_setDoubleOptionValue(
                highs::Ptr{Cvoid},
                option::Ptr{Cchar},
                parse(Float64, value)::Cdouble,
            )::Cint
        else
            @assert typeP[] == Cint(3)  # kHighsOptionTypeString
            @ccall libhighs.Highs_setStringOptionValue(
                highs::Ptr{Cvoid},
                option::Ptr{Cchar},
                value::Ptr{Cchar},
            )::Cint
        end
    end
    run_status = @ccall libhighs.Highs_run(highs::Ptr{Cvoid})::Cint
    total_time = time() - start_time
    X = @ccall libhighs.Highs_versionMajor()::Cint
    Y = @ccall libhighs.Highs_versionMinor()::Cint
    Z = @ccall libhighs.Highs_versionPatch()::Cint
    result = Dict(
        "filename" => filename,
        "options" => parsed_args,
        "version" => "v$X.$Y.$Z",
        "julia_total_time" => total_time,
        "highs_run_time" =>
            @ccall(libhighs.Highs_getRunTime(highs::Ptr{Cvoid})::Cdouble),
        "highs_objective_value" =>
            @ccall(libhighs.Highs_getObjectiveValue(highs::Ptr{Cvoid})::Cdouble),
        "run_status" => run_status,
        "model_status" =>
            @ccall(libhighs.Highs_getModelStatus(highs::Ptr{Cvoid})::Cint),
    )
    # INFO
    pType = Ref{Cint}()
    for info in [
        "simplex_iteration_count",
        "ipm_iteration_count",
        "crossover_iteration_count",
        "primal_solution_status",
        "dual_solution_status",
        "basis_validity",
        "num_primal_infeasibilities",
        "num_dual_infeasibilities",
        "objective_function_value",
        "mip_dual_bound",
        "mip_gap",
        "max_integrality_violation",
        "max_primal_infeasibility",
        "sum_primal_infeasibilities",
        "max_dual_infeasibility",
        "sum_dual_infeasibilities",
    ]
        @ccall libhighs.Highs_getInfoType(
            highs::Ptr{Cvoid},
            info::Ptr{Cchar},
            pType::Ptr{Cint},
        )::Cint
        if pType[] == Cint(1)  # kHighsInfoTypeInt
            pInt = Ref{Cint}()
            @ccall libhighs.Highs_getIntInfoValue(
                highs::Ptr{Cvoid},
                info::Ptr{Cchar},
                pInt::Ptr{Cint},
            )::Cint
            result[info] = pInt[]
        elseif pType[] == Cint(2)  # kHighsInfoTypeDouble
            pDouble = Ref{Cdouble}()
            @ccall libhighs.Highs_getDoubleInfoValue(
                highs::Ptr{Cvoid},
                info::Ptr{Cchar},
                pDouble::Ptr{Cdouble},
            )::Cint
            result[info] = pDouble[]
        end
    end
    @ccall libhighs.Highs_destroy(highs::Ptr{Cvoid})::Cvoid
    return result
end

sgm(x::Vector{BigFloat}; sh::BigFloat) = exp(sum(log(max(1, xi + sh)) for xi in x) / length(x)) - sh
sgm(x; sh = 10.0) = round(Float64(sgm(BigFloat.(x); sh = big(sh))); digits = 2)

function geometric_mean(df, key)
    return DataFrames.combine(
        DataFrames.groupby(
            DataFrames.combine(
                DataFrames.groupby(df, [:filename, :solver_version]),
                key => Statistics.mean => key,
            ),
            [:solver_version]
        ),
        key => sgm => key,
    )
end

function analyse_output(output_filename = "output.jsonl")
    df = DataFrames.DataFrame(JSON.parse.(readlines(output_filename)))
    df.solver = get.(df.options, "solver", "default")
    df.solver_version = string.(df.version, "-", df.solver)
    df.uuid = String.(first.(split.(last.(split.(df.filename, '/')), '-')))
    result = geometric_mean(df, :julia_total_time)
    @info "SGM(sh=10) for :julia_total_time"
    display(result)
    function get_wide(df, key)
        df_long = df[:, [:uuid, :solver_version, key]]
        return DataFrames.unstack(df_long, :uuid, :solver_version, key)
    end
    for key in (:run_status, :model_status, :highs_objective_value)
        @info key
        display(get_wide(df, key))
    end
    return
end

function main(args)
    parsed_args = _parse_args(args)
    output_filename = get(parsed_args, "output_filename", "output.jsonl")
    if get(parsed_args, "help", "false") == "true"
        return print_help()
    elseif get(parsed_args, "analyze", "false") == "true"
        return analyse_output(output_filename)
    end
    instances = String[]
    if get(parsed_args, "all", "false") == "true"
        append!(instances, filter(_is_mps, readdir(INSTANCE_DIR; join = true)))
    else
        push!(instances, joinpath(INSTANCE_DIR, parsed_args["instance"]))
    end
    for instance in instances
        ret = benchmark(instance, parsed_args)
        open(output_filename, "a") do io
            return println(io, JSON.json(ret))
        end
    end
    return
end

main(ARGS)
