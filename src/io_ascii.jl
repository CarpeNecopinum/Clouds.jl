import ZipFile

function saveASCII(f::IO, properties::Vector...)
    @assert length(properties) > 0
    for i in 1:length(properties[1])
        join(f, Base.Iterators.flatten(p[i] for p in properties), " ")
        println(f)
    end
end

function saveASCII(filename::AbstractString, properties::Vector...)
    @assert length(properties) > 0

    open(filename, "w") do f
        saveASCII(f, properties...)
    end
end


function loadASCII(f::IO, types::Type...)
    result = Tuple(Vector{type}() for type in types)
    element_types = eltype.(result)
    scalar_types = eltype.(element_types)
    lengths = map(x->length(Ref{x}()[]), element_types)

    for line in eachline(f)
        parts = split(line, " ")
        offset = 1
        for i in eachindex(result)
            push!(result[i], element_types[i](parse.(scalar_types[i], parts[offset:(offset+lengths[i]-1)])...))
            offset += lengths[i]
        end
    end

    result
end

loadASCII(filename::AbstractString, types::Type...) =
    open(f -> loadASCII(f, types...), filename)

function loadASCII(f::IO; attributes...)
    types = values(attributes)
    names = keys(attributes)
    vectors = loadASCII(f, types...)
    result = PointCloud()
    for i in eachindex(names)
        setproperty!(result, Symbol(names[i]), vectors[i])
    end
    result
end

loadASCII(filename::AbstractString; attributes...) =
    open(f -> loadASCII(f; attributes...), filename)
