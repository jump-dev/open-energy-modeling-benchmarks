# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

using Printf

function work(node, func::Symbol, cont::Ref{Int})
    done = false
    if node.data.sf.func == func
        cont[] += length(node.data.span)
        done = true
    end
    return done
end

function work(node, path_begin::String, cont::Ref{Int})
    done = false
    if startswith(String(node.data.sf.file), path_begin)
        cont[] += length(node.data.span)
        done = true
    end
    return done
end

# LeftChildRightSiblingTrees traversal
function dowork(node, data, cont)
    done = work(node, data, cont)
    if done
        return
    end
    for child in node
        dowork(child, data, cont)
    end
    return
end

function dowork(node, mod::Module, cont)
    return dowork(node, pathof(mod) |> dirname, cont)
end

function get_profile_data(list)

    @info("Processing profile data")

    profiler_data = Profile.fetch()
    profiler_graph = FlameGraphs.flamegraph(profiler_data)
    @assert length(list) > 1

    times = Int[]

    for item in list
        @assert typeof(item) == Symbol || typeof(item) == Module
        val = Ref{Int}(0)
        dowork(profiler_graph, item, val)
        push!(times, val[])
    end

    total = times[1]

    percentages = Float64[]
    for time in times[2:end]
        push!(percentages, time / total * 100)
    end

    result = Dict(zip(Symbol.(list[2:end]), percentages))

    @info("Finished processing profile data")

    return result
end

function create_profile_file(list; basepath = "", header = true, named = "")
    if basepath == ""
        basepath = pwd()
    end
    file_name = joinpath(basepath, "prof.csv")
    if isfile(file_name)
        try
            rm(file_name)
        catch
            @info("Could not remove existing profile file $file_name")
        end
    end
    f = open(file_name, "w")

    if header
        header_str = ""
        if named != ""
            header_str *= "$named,"
        end
        for item in list[2:end]
            header_str *= String(Symbol(item)) * " (%),"
        end
        println(f, header_str[1:end-1])
    end

    return (f, Symbol.(list[2:end]))
end

function write_profile_data(file, result; named = "")
    f, list = file

    str = ""
    if named != ""
        str *= named * ","
    end
    for item in list
        str *= @sprintf("%1.2f", result[item]) * ","
    end
    println(f, str[1:end-1])
    return
end

function close_profile_file(file)
    close(file[1])
    return
end

