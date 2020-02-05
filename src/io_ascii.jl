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

@generated function loadASCII1(filename::AbstractString, types::Type...)
    types = map(x->x.parameters[1], types)
    scalar_types = eltype.(types)
    lengths = map(x->length(Ref{x}()[]), types)
    offsets = [sum([1,lengths[1:i]...]) for i in 0:(length(types)-1)]

    make_result = ()->Tuple(Vector{type}() for type in types)
    filename = esc(filename)

    localparse(::Type{Vec3{T}}, strs, off) where {T} = Vec3{T}(parse(T,strs[off]), parse(T,strs[off+1]), parse(T,strs[off+2]))
    localparse(::Type{T}, strs, off) where {T} = parse(T,strs[off])

    quote
        parts = SubString{String}[]
        result = $(make_result)()
        f = open(filename, "r")
        for line in eachline(f)
            empty!(parts)
            Base._split(line, isequal(' '), 0, false, parts)

            $([:(push!(result[$i], $(localparse)($(types[i]), parts, $(offsets[i])))) for i in 1:length(types)]...)
        end
        close(f)
        result
    end
end

function loadASCII(filename::AbstractString, types::Type...)
    result = Tuple(Vector{type}() for type in types)
    element_types = eltype.(result)
    scalar_types = eltype.(element_types)
    lengths = map(x->length(Ref{x}()[]), element_types)
    println(lengths)

    open(filename, "r") do f
        for line in eachline(f)
            parts = split(line, " ")
            offset = 1
            for i in eachindex(result)
                push!(result[i], element_types[i](parse.(scalar_types[i], parts[offset:(offset+lengths[i]-1)])...))
                offset += lengths[i]
            end
        end
    end
    result
end
