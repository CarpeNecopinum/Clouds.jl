abstract type AbstractGridFilter end

"""
    `KeepFirstGridFilter`

    A simple grid filter that only keeps the first point added to each cell.
"""
struct KeepFirstGridFilter <: AbstractGridFilter
    cloud::PointCloud
    edgelen::Float32
    full_cells::Set{Vec3{Int32}}
end

KeepFirstGridFilter(edgelen::Real) = KeepFirstGridFilter(PointCloud(), edgelen, Set{Vec3{Int32}}())

"""
    test_push!(set::AbstractSet, value)

Insert `value` into the `set`.

If the `set` already contained `value`, return false.
If `value` was newly inserted into `set`, return true.
"""
function test_push!(set::AbstractSet, v)
    old_len = length(set)
    push!(set, v)
    old_len != length(set)
end

"""
    insert!(filter::KeepFirstGridFilter, positions, cloud::PointCloud)

Insert `cloud` into the filtered PointCloud held by `filter`.
Use `positions` as point coordinates for the grid filtering.
"""
function Base.insert!(filter::KeepFirstGridFilter, positions, cloud::PointCloud)
    # Identify indices that need to be copied over
    copy = Int32[]
    @showprogress "Filtering... " 1 for i in 1:length(cloud)
        key = floor.(Int32, positions[i] / filter.edgelen)
        if test_push!(filter.full_cells, key)
            push!(copy, i)
        end
    end

    # Copy attributes over
    for (key, value) in cloud.point_attributes
        if !haskey(filter.cloud, key)
            setproperty!(filter.cloud, key, similar(value, length(filter.cloud)))
        end
        append!(filter.cloud[key], value[copy])
    end
end

"""
    append!(filter::KeepFirstGridFilter, cloud::PointCloud)

Insert `cloud` into the filtered PointCloud held by `filter`.
Use cloud.positions as point coordinates for the filtering.
"""
Base.append!(filter::KeepFirstGridFilter, cloud::PointCloud) = insert!(filter, cloud.positions, cloud)
