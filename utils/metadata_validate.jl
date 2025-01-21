cd(@__DIR__)

import TOML

function validate()

    instances_path = joinpath(pwd(), "..", "instances")

    metadata = TOML.parsefile(joinpath(instances_path, "metadata.toml"))["instance"]

    files = readdir(instances_path, sort=true, join=false)

    # remove ignored files
    to_remove_name_start = ["metadata.toml", "."]
    to_remove_indices = Int[]
    for (i, file) in enumerate(files)
        if any(startswith(file, name_start) for name_start in to_remove_name_start)
            push!(to_remove_indices, i)
        end
    end
    deleteat!(files, to_remove_indices)

    metadata_names = map(data -> data["name"], metadata)

    failed_to_validate = false

    for (i, name) in enumerate(metadata_names)
        for (j, name) in enumerate(metadata_names)
            if i != j
                if metadata_names[i] == metadata_names[j]
                    println("Duplicate file name in metadata.toml: ", metadata_names[i])
                    failed_to_validate = true
                end
            end
        end
    end

    for file in files
        if !(file in metadata_names)
            println("File not in metadata.toml: ", file)
            failed_to_validate = true
        end
    end

    for name in metadata_names
        if !(name in files)
            println("Name from metada.toml not in files: ", name)
            failed_to_validate = true
        end
    end

    @assert length(metadata) == length(files)

    # get keys
    data_keys = keys(metadata[1])

    for data in metadata
        if !(data["name"] in files)
            println("Name from metada.toml not in files: ", data["name"])
            failed_to_validate = true
        end
        for key in data_keys
            if !haskey(data, key)
                println("Key \"", key, "\" not found for: \"", data["name"], "\"")
                failed_to_validate = true
            end
        end
        for key in keys(data)
            if !(key in data_keys)
                println("Key \"", key, "\" not not expected for: \"", data["name"], "\"")
                failed_to_validate = true
            end
        end
    end

    if failed_to_validate
        error("Validation failed")
    else
        println("Validation passed")
    end

    return
end

validate()