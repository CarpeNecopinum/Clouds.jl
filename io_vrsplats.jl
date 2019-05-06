import GZip

using ProgressMeter
struct Splat
    pos::Point3f0
    normal::Vec3f0
    color::Vec4{UInt8}
end

const Point3i = Point3{Int32}
function gridify(cloud::PointCloud; cell_size = 4f0)
    dic = Dict{Point3{Int32}, Vector{Splat}}()
    progress = Progress(length(cloud.positions) ÷ 100000, "Assigning vertices to cells")
    for (i,p) in enumerate(cloud.positions)
        (i % 100000 != 0) || next!(progress)
        key = Point3i(Int32.(round.(p ./ cell_size))) .* cell_size
        dic[key] = push!(get(dic, key, Vector{Splat}()), Splat(p, cloud[:normal][i], cloud[:color][i]))
    end
    (dic, cell_size)
end

function bgra_to_rgb(color::UInt32)
    bytes = reinterpret(UInt8, [color])
    @SVector UInt8[bytes[4], bytes[3], bytes[2]]
end

struct Vertex
    pos::Point{3,UInt8}
    tangent::Point{3,UInt8}
    bitangent::Point{3,UInt8}
    normal_len::UInt8
    color::SVector{3,UInt8}
    layer::UInt8
end

struct Cell
    bbmin::Point3f0
    bbmax::Point3f0

    index_min::UInt32
    index_max::UInt32
end

using LinearAlgebra: ×, normalize
compress_vec(v::Vec3f0) = Vec3{UInt8}(floor.(v .* 127.5f0 .+ 127.5f0))
compress_pos(p::Point3f0, bbmin::Point3f0, bbmax::Point3f0) = Vec3{UInt8}(floor.((p .- bbmin) ./ (bbmax - bbmin) .* 255.0))
compress_pos(Point3f0(0,1,1), Point3f0(0,0,0), Point3f0(1,1,1))
function saveVRSplats(grid::Tuple{Dict{Point3{Int32}, Vector{Splat}},CellSize}, filename::AbstractString) where {CellSize}
    dic = grid[1]
    cellsize = grid[2]
    verts = Vector{Vertex}()
    cells = Vector{Cell}()

    GZip.open(filename, "w") do f
        p = Progress(length(dic), 1, "Collecting cells: ")
        for (k,v) in dic
            cell = Cell(k .- cellsize .* 0.5, k .+ cellsize .* 0.5, length(verts), length(v))
            push!(cells, cell)
            append!(verts,
                Vertex(
                    compress_pos(x.pos, cell.bbmin, cell.bbmax),
                    Point3{UInt8}(0,0,0),
                    Point3{UInt8}(0,0,0),
                    0x00,
                    x.color[1:3],
                    0x00)
                for x in v)
            next!(p)
        end

        p = ProgressUnknown(1, "Writing .vrsplats header.")
        next!(p)
        write(f, UInt32(4)) # version
        write(f, UInt32(length(verts)))
        write(f, UInt32(length(cells)))

        p = ProgressUnknown(1, "Writing vertices.")
        next!(p)
        write(f, verts)
        p = ProgressUnknown(1, "Writing cells.")
        next!(p)
        write(f, cells)
    end
end

function saveVRSplats(cloud::PointCloud, filename::AbstractString)
    dic = gridify(cloud)
    saveVRSplats(dic, filename)
end
