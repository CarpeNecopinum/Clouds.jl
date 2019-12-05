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
    into
end

function loadPBRBIN_content(type::Val{2}, f)
    n_points = read!(f, Ref{Int32}())[]
    cloud = PointCloud(;positions = zeros(Vec3f0, n_points),
        normals = zeros(Vec3f0, n_points),
        radii = zeros(Float32, n_points),
        colors = zeros(Vec4{UInt8}, n_points))

    print(stderr, "\rLoading $n_points points\u1b[K")
    loadCompressed!(f, cloud.positions)

    print(stderr, "\rLoading $n_points normals\u1b[K")
    loadCompressed!(f, cloud.normals)

    print(stderr, "\rLoading $n_points radii\u1b[K")
    loadCompressed!(f, cloud.radii)

    print(stderr, "\rLoading $n_points colors\u1b[K")
    loadCompressed!(f, cloud.colors)

    cloud
end

const PBRBinPropTypes = Dict{UInt32, DataType}(
    0 => Float32,
    1 => Vec2f0,
    2 => Vec3f0,
    3 => Float64,
    6 => Int32,
    15 => UInt32,
    18 => UInt16
)

function loadPBRBIN_content(type::Val{3}, f)
    n_points = read!(f, Ref{Int32}())[]
    n_props = read!(f, Ref{Int32}())[]
    @show n_points, n_props

    props = Dict{Symbol,Vector}()
    for prop_id in 1:n_props
        n_chars = read!(f, Ref{Int32}())[]
        prop_name = read!(f, Vector{UInt8}(undef, n_chars)) |> String
        prop_type = PBRBinPropTypes[read!(f, Ref{UInt32}())[]]
        @show prop_type
        props[Symbol(prop_name)] = loadCompressed!(f, Vector{prop_type}(undef, n_points))
    end

    if haskey(props, :Colors)
        props[:Colors] = reinterpret(RGB24, props[:Colors]) |> collect
    end

    PointCloud(; props...)
end

function loadPBRBIN(filename::AbstractString)
    print(stderr, "Reading PBRBin...")
    prog = ProgressUnknown("Reading PBRBin:\u1b[K")
    cloud = open(filename, "r") do f
        type = read!(f, Ref{Int32}())[]
        loadPBRBIN_content(Val(Int(type)), f)
    end

    if hasfield(typeof(cloud), :colors)
        color = cloud.colors
        for i in eachindex(color)
            c = color[i]
            color[i] = Vec4(c[3], c[2], c[1], c[4])
        end
    end

    cloud
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
        @assert eltype(cloud.positions[1]) === Float32 "PBRbin can only store clouds with float positions"
        @assert length(cloud.positions[1]) === 3 "PBRbin can only store 3D points"
        storeCompressed(f, cloud.positions)

        print(stderr, "\rSaving $n_points normals\u1b[K")
        @assert eltype(cloud.normals[1]) === Float32 "PBRbin can only store clouds with float normals"
        @assert length(cloud.normals[1]) === 3 "PBRbin can only store 3D normals"
        storeCompressed(f, cloud.normals)

        print(stderr, "\rSaving $n_points radii\u1b[K")
        @assert eltype(cloud.radii) === Float32 "PBRbin can only store clouds with float radii"
        storeCompressed(f, cloud.radii)

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
