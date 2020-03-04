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

function Base.append!(filter::KeepFirstGridFilter, cloud::PointCloud)
    # Identify indices that need to be copied over
    copy = Int32[]
    @showprogress "Filtering... " 1 for i in 1:length(cloud)
        key = floor.(Int32, cloud.positions[i] / filter.edgelen)
        if test_push!(filter.full_cells, key)
            push!(copy, i)
        end
    end

    println(copy)

    # Copy attributes over
    for (key, value) in cloud.point_attributes
        if !haskey(filter.cloud, key)
            setproperty!(filter.cloud, key, similar(value, length(filter.cloud)))
        end
        append!(filter.cloud[key], value[copy])
    end
    filter
end
