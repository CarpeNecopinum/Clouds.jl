function saveASCII(f::IO, attributes::Vector...)
    @assert length(attributes) > 0
    for i in 1:length(attributes[1])
        join(f, Base.Iterators.flatten(p[i] for p in attributes), " ")
        println(f)
    end
end

function saveASCII(filename::AbstractString, attributes::Vector...)
    @assert length(attributes) > 0

    open(filename, "w") do f
        saveASCII(f, attributes...)
    end
end

"""
    saveASCII(::Union{AbstractString,IO}, attributes::Vector...)

Store the `attributes` as XYZ / ASCII point cloud file.
The format of the lines will adapt to the types of the attributes provided.

```jldoctest
io = IOBuffer()

Clouds.saveASCII(io, cloud.positions)
Text(String(take!(io)))

#output

0.0 0.0 0.0
0.0 0.0 0.0
0.0 0.0 0.0
```
"""
saveASCII


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


"""
    loadASCII(f::Union{AbstractString,IO}; attributes...)

Loads `f` as PointCloud. The attributes to load are provided as keyword arguments, where the
key corresponds to the attribute name and the value corresponds to the eltype of the Vector.

    loadASCII(f::Union{AbstractString,IO}, types::Type...)

Loads `f` as a Tuple with one element per type in `types`.

"""
loadASCII
