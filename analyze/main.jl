# Copyright (c) 2024: Oscar Dowson, Joaquim Garcia and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

cd(@__DIR__)

using JuMP
import MathOptAnalyzer
import Printf
import DelimitedFiles

function analyze()
    instances_path = joinpath(@__DIR__, "..", "instances")

    instances = String[]
    _is_mps(c) = endswith(c, ".mps.gz")
    append!(instances, filter(_is_mps, readdir(instances_path; join = true)))

    all = Dict{String,Dict{String,Any}}()
    n = length(instances)
    for (i, instance) in enumerate(instances)
        Printf.@printf("Analyzing %d/%d: %s\n", i, n, instance)
        @time model = read_from_file(instance)
        @time data =
            MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
        list = MathOptAnalyzer.list_of_issue_types(data)
        dict = Dict{String,Any}()
        for issue_type in list
            issues = MathOptAnalyzer.list_of_issues(data, issue_type)
            dict[string(issue_type)] = length(issues)
            if length(issues) >= 1
                val = ""
                try
                    val = string(MathOptAnalyzer.value(issues[1]))
                    dict[string(issue_type)*"_value"] = val
                catch e
                    # do nothing if value cannot be retrieved
                end
            end
        end
        all[instance] = dict
    end

    return all
end

function write_to_csv(out)
    lines = sort(collect(keys(out)))
    cols = String[]

    for (name, dict) in out
        for k in keys(dict)
            if !(k in cols)
                push!(cols, k)
            end
        end
    end
    sort!(cols)

    mat = Matrix{String}(undef, length(lines), length(cols))
    for (i, line) in enumerate(lines)
        for (j, col) in enumerate(cols)
            mat[i, j] = string(get(out[line], col, ""))
        end
    end

    beg = "MathOptAnalyzer.Numerical."
    for i in eachindex(cols)
        if startswith(cols[i], beg)
            cols[i] = cols[i][length(beg)+1:end]  # remove prefix
        end
    end

    pushfirst!(cols, "instance")

    for i in eachindex(lines)
        lines[i] = join(split(splitpath(lines[i])[end], '-')[1:end-1], "-")
    end

    mat = hcat(lines, mat)
    mat = vcat(reshape(cols, 1, length(cols)), mat)

    DelimitedFiles.writedlm("summary.csv", mat, ',')

    return
end

@time out = analyze()

write_to_csv(out)
