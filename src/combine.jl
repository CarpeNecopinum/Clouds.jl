
struct CloudGridV2{Cloud <: PointCloud}
    cloud::Cloud
    edgeLen::Float32
    grid::Set{Vec3{Int32}}
end

CloudGrid = CloudGridV2
CloudGridV2(edgeLen::Float32) = CloudGridV2(PointCloud(), edgeLen, Set{Vec3{Int32}}())

function insert_cloud!(grid::CloudGrid, cloud::PointCloud)
    copy = Int32[]
    @showprogress "Filtering... " 1 for i in 1:length(cloud)
        key = floor.(Int32, cloud.positions[i] / grid.edgeLen)
        if !(key in grid.grid)
            push!(grid.grid, key)
            push!(copy, i)
        end
    end

    for (key, value) in cloud.attributes
        haskey(grid.cloud, key) || (grid.cloud[key] = similar(value, length(grid.cloud)))
        append!(grid.cloud[key], value[copy])
    end
    append!(grid.cloud.positions, cloud.positions[copy])
    grid
end

function grid_union(clouds::AbstractVector{T}, edgeLen::Float32) where {T<:PointCloud}
    grid = CloudGrid(edgeLen)

    @showprogress "Inserting clouds..." for cloud in clouds
        insert_cloud!(grid, cloud)
    end
    grid.cloud
end

function gridfilter(cloud::PointCloud, edgeLen::Float32)
    grid = CloudGrid(edgeLen)
    insert_cloud!(grid, cloud)
    grid.cloud
end
