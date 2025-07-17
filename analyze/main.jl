using JuMP, MathOptAnalyzer, Printf

function analyze()
    @show instances_path = joinpath(@__DIR__, "..", "instances")

    instances = String[]
    _is_mps(c) = endswith(c, ".mps.gz")
    append!(instances, filter(_is_mps, readdir(instances_path; join = true)))

    all = Dict{String,Dict{String,Int}}()
    n = length(instances)
    for (i, instance) in enumerate(instances)
        @printf("Analyzing %d/%d: %s\n", i, n, instance)
        model = read_from_file(instance)
        data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
        list = MathOptAnalyzer.list_of_issue_types(data)
        dict = Dict{String,Int}()
        for issue_type in list
            issues = MathOptAnalyzer.list_of_issues(data, issue_type)
            dict[string(issue_type)] = length(issues)
        end
        all[instance] = dict
    end

    @show all
    return all
end

analyze()
