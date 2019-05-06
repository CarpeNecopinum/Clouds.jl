using FileIO
using Snappy
import GeometryTypes
const Vec3f0 = GeometryTypes.Vec3f0
const Point3f0 = GeometryTypes.Point3f0
using ColorTypes
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

    PointCloud(temp.positions, temp.attributes)ra
end
