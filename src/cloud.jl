using StaticArrays

"""
    `PointCloud()`

    Constructs a PointCloud that can hold point and cloud attributes.
    Point attributes are Vectors with as many entries as points in the cloud.
    Cloud attributes can be any object, independent of cloud size.


    Indexing on a PointCloud is used to access cloud attributes, while


    ```julia
        cloud = PointCloud() # create an empty PointCloud
        cloud[:name] = "My Point Cloud" # name as cloud attribute
        cloud.positions = rand(Vec3f0, 100) # positions as point attribute
    ```
"""
struct PointCloud
    point_attributes::Dict{Symbol, Vector}
    cloud_attributes::Dict{Symbol, Any}
end

function PointCloud(; point_properties...)
    cloud = PointCloud(Dict{Symbol,Vector}(), Dict{Symbol, Any}())
    for prop in point_properties
        setproperty!(cloud, prop[1], prop[2])
    end
    cloud
end

PointCloud(point_attrs::Dict{Symbol, Vector}) = PointCloud(point_attrs, Dict{Symbol, Any}())


function Base.getproperty(cloud::PointCloud, name::Symbol)
    if haskey(getfield(cloud, :point_attributes), name)
        getfield(cloud, :point_attributes)[name]
    elseif haskey(getfield(cloud, :cloud_attributes), name)
        getfield(cloud, :cloud_attributes)[name]
    else
        getfield(cloud, name)
    end
end

function Base.getindex(cloud::PointCloud, attrname::Union{Symbol,String})
    name = Symbol(attrname)
    if haskey(getfield(cloud, :cloud_attributes), name)
        getfield(cloud, :cloud_attributes)[name]
    elseif haskey(getfield(cloud, :point_attributes), name)
        getfield(cloud, :point_attributes)[name]
    else
        throw(KeyError(name))
    end
end

function Base.propertynames(cloud::PointCloud)
    (keys(cloud.point_attributes)..., keys(cloud.cloud_attributes)..., fieldnames(PointCloud)...)
end

"""
    `length(PointCloud)`

    Get the number of points in the PointCloud.
"""
function Base.length(cloud::PointCloud)
    if !isempty(cloud.point_attributes)
        length(first(cloud.point_attributes)[2])
    else
        0
    end
end

Base.show(io::IO,cloud::PointCloud) = print(io,"$(typeof(cloud))(length=$(length(cloud)), $(keys(cloud.point_attributes)), $(keys(cloud.cloud_attributes)))")

function Base.setindex!(cloud::PointCloud, val, attrname::Union{Symbol,String})
    setindex!(cloud.cloud_attributes, val, Symbol(attrname))
    cloud
end

function Base.setproperty!(cloud::PointCloud, attrname::Symbol, val)
    if hasfield(PointCloud, attrname)
        setfield!(cloud, val, attrname)
    else
        @assert (length(cloud) == 0) || (length(cloud) == length(val)) "Cannot set point attribute $(attrname): PointCloud has size $(length(cloud)), but the new attribute has size $(length(val))"
        setindex!(cloud.point_attributes, val, attrname)
    end
end

function Base.delete!(cloud::PointCloud, key::Symbol)
    if haskey(cloud.cloud_attributes, key)
        delete!(cloud.cloud_attributes, key)
    else
        delete!(cloud.point_attributes, key)
    end
    cloud
end

function Base.haskey(cloud::PointCloud, key::Symbol)
    return haskey(cloud.cloud_attributes, key) || haskey(cloud.point_attributes, key)
end

function reorder!(cloud::PointCloud, indices::AbstractArray)
    for attr in values(cloud.point_attributes)
        attr .= attr[indices]
    end
end

function Base.resize!(cloud::PointCloud, size::Integer)
    for arr in cloud.data
        resize!(arr, size)
    end
end
