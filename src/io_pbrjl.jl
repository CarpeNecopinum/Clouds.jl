function savePBRJL(cloud::PointCloud, f::IO)
    println(f, length(cloud))
    println(f, length(cloud.attributes) + 1)

    println(f, "position", " ", eltype(cloud.positions))

    for (key,val) in cloud.attributes
        println(f, key, " ", eltype(val))
    end

    println(position(f))

    write(f, cloud.positions)
    flush(f)

    for (key,val) in cloud.attributes
        write(f, val)
        flush(f)
    end
end


function savePBRJL(cloud::PointCloud, filename::AbstractString)
    open(filename, "w") do f
        endswith(filename, ".gz") && (f = CodecZlib.GzipCompressorStream(f))
        savePBRJL(cloud, f)
    end
end

function loadPBRJL(f::IO)
    len = parse(Int, readline(f))
    n_attribs = parse(Int, readline(f))

    attribs = Vector{Pair{Symbol,Vector}}()
    for i in 1:n_attribs
        name, typestring = split(readline(f))
        type = eval(Meta.parse(typestring))
        push!(attribs, Symbol(name) => Vector{type}(undef, len))
    end

    for (name, arr) in attribs
        read!(f, arr)
    end
    dict = Dict(attribs)
    dict[:positions] = dict[:position]
    delete!(dict[:position])
    PointCloud(dict...)
end

function loadPBRJL(filename::AbstractString)
    open(filename, "r") do f
        endswith(filename, ".gz") && (f = CodecZlib.GzipDecompressorStream(f))
        loadPBRJL(f)
    end
end
