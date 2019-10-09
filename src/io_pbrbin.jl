using FileIO
using Snappy
import NearestNeighbors
NN = NearestNeighbors


using ProgressMeter

function loadCompressed!(io::IO, into::Vector{T}) where {T}
    compressed_size = read!(io, Ref{UInt64}())[]
    compressed_data = Vector{UInt8}(undef, compressed_size)
    read!(io, compressed_data)

    uncompressed_data = Snappy.uncompress(compressed_data)
    into .= reinterpret(T, uncompressed_data)
end

function loadPBRBIN(filename::AbstractString)
    print(stderr, "Reading PBRBin...")
    prog = ProgressUnknown("Reading PBRBin:\u1b[K")
    temp = PointCloud{3,Float32,Nothing}()
    open(filename, "r") do f
        type = read!(f, Ref{Int32}())[]
        @assert type == 2

        n_points = read!(f, Ref{Int32}())[]

        print(stderr, "\rLoading $n_points points\u1b[K")
        resize!(temp.positions, n_points)
        loadCompressed!(f, temp.positions)

        print(stderr, "\rLoading $n_points normals\u1b[K")
        temp[:normal] = Vector{Vec3f0}(undef, n_points)
        loadCompressed!(f, temp[:normal]::Vector{Vec3f0})

        print(stderr, "\rLoading $n_points radii\u1b[K")
        temp[:radius] = Vector{Float32}(undef, n_points)
        loadCompressed!(f, temp[:radius]::Vector{Float32})

        print(stderr, "\rLoading $n_points colors\u1b[K")
        temp[:color] = Vector{Vec4{UInt8}}(undef, n_points)
        loadCompressed!(f, temp[:color]::Vector{Vec4{UInt8}})
    end

    color = temp[:color]::Vector{Vec4{UInt8}}
    for i in eachindex(color)
        c = color[i]
        color[i] = Vec4(c[3], c[2], c[1], c[4])
    end

    PointCloud(temp.positions, temp.attributes)
end

function storeCompressed(io::IO, vec::Vector)
    write(io, UInt64(length(vec)))
    write(io, Snappy.compress(Vector{UInt8}(reinterpret(UInt8, vec))))
end

function savePBRBIN(cloud::PointCloud, filename::AbstractString)
    print(stderr, "Saving PBRBin...")
    open(filename, "w") do f
        write(f, Int32(2)) # type = Compressed PBR bin

        n_points = length(cloud)
        write(f, Int32(n_points))

        print(stderr, "\rSaving $n_points points\u1b[K")
        storeCompressed(f, cloud.positions)

        print(stderr, "\rSaving $n_points normals\u1b[K")
        storeCompressed(f, cloud[:normal]::Vector{Vec3f0})

        print(stderr, "\rSaving $n_points radii\u1b[K")
        storeCompressed(f, cloud[:radius]::Vector{Float32})

        print(stderr, "\rShuffling colors[K")
        color = copy(cloud[:color]::Vector{Vec4{UInt8}})
        for i in eachindex(color)
            c = color[i]
            color[i] = Vec4(c[3], c[2], c[1], c[4])
        end

        print(stderr, "\rSaving $n_points colors\u1b[K")
        storeCompressed(f, color)
    end
end
