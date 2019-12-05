using StaticArrays

struct PointCloud{DataT <: NamedTuple}
    data::DataT
end

PointCloud(;kwargs...) = PointCloud(values(kwargs))

# functions to pin some often used attributes to one name
positions(cloud::PointCloud) = cloud.positions
normals(cloud::PointCloud) = cloud.normals
tree(cloud::PointCloud) = cloud.tree

function Base.getproperty(cloud::PointCloud, name::Symbol)
    if haskey(getfield(cloud, :data), name)
        getfield(cloud, :data)[name]
    else
        getfield(cloud, name)
    end
end

function Base.propertynames(cloud::PointCloud)
    return (fieldnames(typeof(cloud))..., fieldnames(typeof(getfield(cloud, :data)))...)
end

function Base.length(cloud::PointCloud)
    haskey(cloud.data, :positions) && return length(positions(cloud))
    haskey(cloud.data, :normals) && return length(normals(cloud))
    haskey(cloud.data, 1) && return length(cloud.data[1])
    return 0
end

function add(cloud::PointCloud; kw_args...)
    PointCloud(; cloud.data..., kw_args...)
end

#add_kdtree(cloud::PointCloud) = add(cloud; tree = NN.KDTree(positions(cloud), NN.Euclidean(); leafsize = 64))

function add_kdtree(cloud::PointCloud)
    tree = NN.DataFreeTree(NN.KDTree, positions(cloud), NN.Euclidean(); leafsize = 64)
    add(cloud; tree = injectdata(tree, positions(cloud)))
end

Base.show(io::IO,cloud::PointCloud) = print(io,"$(typeof(cloud))(length=$(length(cloud)), $(keys(cloud.data))")

Base.getindex(cloud::PointCloud, attrname::Union{Symbol,String}) = getfield(cloud.data, Symbol(attrname))

# function Base.getindex(cloud::PointCloud, attrname::Symbol)
#     haskey(cloud, attrname) || error("Point cloud $cloud has no attribute $attrname")
#     cloud.attributes[attrname]
# end

# function Base.getindex(cloud::PointCloud{Dim,T,Nothing}, row_inds::AbstractVector) where {Dim,T}
#     pos = positions(cloud)[row_inds]
#     attrs = Dict{Symbol,Vector}()
#     for (k,v) in cloud.attributes
#         attrs[k] = v[row_inds]
#     end
#     PointCloud{Dim,T,Nothing}(pos, nothing, attrs)
# end

# function PointCloud(positions::Vector{Vec{Dim,T}}, attributes::Dict{Symbol,Vector}; debug = false) where {Dim, T}
#     debug && println("Generating initial KD-Tree")
#     tree = NN.KDTree(positions, NN.Euclidean(); leafsize = 64, reorder = true)
#     return PointCloud(positions, tree, attributes)
#
#     debug && println("Reshuffling cloud attributes reverse")
#     haskey(attributes, :original_index) || (attributes[:original_index] = Vector{Int}(1:length(positions)))
#     positions[tree.indices] .= positions
#     for (key, value) in attributes
#         value[tree.indices] .= value
#     end
#
#     debug && println("Building final KD-Tree")
#     tree = NN.KDTree(positions, tree.hyper_rec, Vector{Int}(1:length(positions)), tree.metric, tree.nodes, tree.tree_data, true)
#     PointCloud(positions, tree, attributes)
# end
#
# function PointCloud(positions::Vector{Vec{Dim,T}}; attributes...) where {Dim, T}
#     PointCloud(positions, convert(Dict{Symbol,Vector}, attributes))
# end

#withkdtree(cloud::PointCloud) = PointCloud(cloud.positions, cloud.attributes)

#positions(cloud::PointCloud) = cloud.positions
#normals(cloud::PointCloud) = cloud[:normal]::Vector{Vec3f0}
#Base.keys(cloud::PointCloud) = keys(cloud.attributes)
#Base.haskey(cloud::PointCloud, attrname::Symbol) = haskey(cloud.attributes, attrname)
#Base.length(cloud::PointCloud) = length(cloud.positions)
#Base.show(io::IO,cloud::PointCloud) = print(io,"$(typeof(cloud))(length=$(length(cloud)), $(keys(cloud.attributes))")
#Base.delete!(cloud::PointCloud, attrname::Symbol) = delete!(cloud.attributes, attrname)
#

#

#
# function split_cloud(allpoints::PointCloud, scanid)
#     unique_scans = unique(scanid)
#     scans = Dict{eltype(unique_scans), typeof(allpoints)}()
#     for id in unique_scans
#         scans[id] = allpoints[id .== scanid]
#     end
#     scans
# end
#
function Base.resize!(cloud::PointCloud, size::Integer)
    for arr in cloud.data
        resize!(arr, size)
    end
end
#
# function Base.setindex!(cloud::PointCloud, value::Vector, attrname::Symbol)
#     if length(value) != length(cloud)
#         error("length($attrname) = $(length(value)) not equal to number of points = $(length(cloud))")
#     end
#     cloud.attributes[attrname] = value
# end
#
# function combine_clouds!(sources::AbstractArray)
#     target = (typeof(sources[1]))()
#     for source in sources
#         n_points_old = length(target)
#         resize!(target, n_points_old + length(source))
#         target.positions[(n_points_old + 1):end] .= source.positions
#         for (key, vec) in source.attributes
#             haskey(target,key) || (target[key] = similar(vec, length(target)))
#             target[key][(n_points_old + 1):end] .= vec
#         end
#     end
#     target
# end
#
# function Base.filter!(pred, cloud::PointCloud)
#     keep = pred.(1:length(cloud))::BitVector
#     (!all(keep)) || return cloud
#
#     ps = cloud.positions[keep]
#     resize!(cloud.positions, length(ps))
#     cloud.positions .= ps
#
#     for (key, val) in cloud.attributes
#         cloud.attributes[key] = val[keep]
#     end
#
#     withkdtree(cloud)
# end
