# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import Profile
import FlameGraphs
import JSON
import Dates

# example usage

# function f1(a)
#     sleep(1)
#     return f2()
# end

# function f2()
#     sleep(2)
#     return
# end

# @list_profile f1(3) [:f2,]

# obtain duration of a specific function and every call below it
# hence this stops the recursion
function add_duration(node, function_symbol::Symbol, cont::Ref{Int})
    done = false
    if node.data.sf.func == function_symbol
        cont[] += length(node.data.span)
        done = true
    end
    return done
end

# obtain duration of any function from module `module_path` function and
# every call below it hence this stops the recursion
function add_duration(node, module_path::String, cont::Ref{Int})
    done = false
    if startswith(String(node.data.sf.file), module_path)
        cont[] += length(node.data.span)
        done = true
    end
    return done
end

# LeftChildRightSiblingTrees.jl traversal
function get_duration(node, data, cont)
    done = add_duration(node, data, cont)
    if done
        return
    end
    for child in node
        get_duration(child, data, cont)
    end
    return
end

function get_duration(node, mod::Module)
    cont = Ref{Int}(0)
    get_duration(node, pathof(mod) |> dirname, cont)
    return cont[]
end

function get_duration(node, func::Symbol)
    cont = Ref{Int}(0)
    get_duration(node, func, cont)
    return cont[]
end

function get_profile_data(list)
    profiler_data = Profile.fetch()
    profiler_graph = FlameGraphs.flamegraph(profiler_data)
    @assert length(list) > 1

    result = Pair{Symbol,Int}[]

    for item in list
        if !(typeof(item) == Symbol || typeof(item) == Module)
            error(
                "Invalid type for item in list, expected Symbol or Module and got $(typeof(item))",
            )
        end
        time = get_duration(profiler_graph, item)
        push!(result, Symbol(item) => time)
    end

    return result
end

function proflist(list, time = nothing; verbose = true)
    if verbose
        @info("Processing profile data")
    end

    prof = get_profile_data(list)

    prof1 = prof[1]

    result = Dict{String,Any}("total_time" => time)

    for (name, data) in prof
        if name != prof1[1]
            _time = if time === nothing
                data / prof1[2]
            else
                time * data / prof1[2]
            end
            result[String(name)] = _time
        end
    end

    if verbose
        @info("Finished processing profile data")
    end

    return result
end

macro proflist(exp, list)
    val = Meta.quot(exp.args[1])
    if typeof(val) != Symbol
        val = Meta.quot(exp.args[1].args[2].value)
    end
    return quote
        list2 = copy($(esc(list)))
        pushfirst!(list2, $val)

        Profile.clear()

        time = @elapsed begin
            Profile.@profile $(esc(exp))
        end

        ret = proflist(list2, time; verbose = true)

        ret
    end
end

function save_proflist(
    data;
    output_filename = "profile.jsonl",
    label = "_name_",
)
    data["name"] = label
    data["date"] = string(Dates.now())
    open(output_filename, "a") do io
        return println(io, JSON.json(data))
    end
    return nothing
end
