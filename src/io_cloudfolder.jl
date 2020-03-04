import Mmap: mmap, sync!
using FileIO: load, save

struct CloudFolder
    path::String
end

point_attributes_file(folder::CloudFolder) = joinpath(folder.path, "point_attributes.txt")
cloud_attributes_file(folder::CloudFolder) = joinpath(folder.path, "cloud_attributes.jld2")

function read_attribute_types(file)
    result = Dict{Symbol, DataType}()
    if ispath(file)
        open(file) do f
            while !eof(f)
                typename, attrname = readline(f) |> split
                type = Meta.parse(typename) |> eval
                result[Symbol(attrname)] = type
            end
        end
    end
    result
end

function read_attrs(folder, file; singleton = false)
    result = Dict{Symbol, Array}()
    types = read_attribute_types(file)
    for (k,v) in pairs(types)
        mapped = if singleton
            mmap(open(joinpath(folder, "$(k).bin"), read = true, write = true, truncate = false), Array{v,0}, ())
        else
            mmap(open(joinpath(folder, "$(k).bin"), read = true, write = true, truncate = false), Vector{v})
        end
        result[k] = mapped
    end
    result
end

function default_state(::Type{T}) where {T}
    @assert !isempty(methods(T,())) "To use a non-bits type as attribute, define a default constructor or overload Clouds.default_state(::Type{T}) for it."
    T()
end

function add_attribute_impl(folder::CloudFolder, textfile::String, attr::Pair{Symbol,DataType}, ignore_existing::Bool, check_type::Bool, n_elements::Int)
    if !isdir(folder.path)
        mkdir(folder.path)
    end

    filename = joinpath(folder.path, "$(attr[1]).bin")
    if !ispath(filename)
        open(textfile; append = true) do f
            println(f, "$(attr[2]) $(attr[1])")
        end
        open(filename; write = true) do f
            truncate(f, n_elements * sizeof(attr[2]))
        end
    elseif !ignore_existing
        error("Attribute $(attr[1]) already exists in folder")
    elseif check_type
        attrs = read_attribute_types(textfile)
        if (attrs[attr[1]] != attr[2])
            error("Attribute $(attr[1]) already exists with different type $(attrs[attr[1]]) vs $(attr[2])")
        end
    end
    folder
end

function num_points(folder::CloudFolder)
    types = read_attribute_types(point_attributes_file(folder))
    !isempty(types) || (return 0)
    name, type = first(types)
    filename = joinpath(folder.path, "$(name).bin")
    stat(filename).size ÷ sizeof(type)
end

"""
    add_point_attribute(folder, attr::Pair{Symbol,DataType};
        gnore_existing = true, check_type = true)

    Add a point attribute (Vector that is resized together with the cloud) of
    the given name => type to the folder.
"""
function add_point_attribute(folder::CloudFolder, attr::Pair{Symbol,DataType}; ignore_existing = true, check_type = true)
    add_attribute_impl(folder, point_attributes_file(folder), attr, ignore_existing, check_type, num_points(folder))
end


"""
    mmap(::CloudFolder)

    Map the binary files of the point cloud folder into memory and return a
    PointCloud assembled from those
"""
function mmap(folder::CloudFolder)
    @assert ispath(folder.path)

    point_attributes = read_attrs(folder.path, point_attributes_file(folder))

    caf = cloud_attributes_file(folder)
    cloud_attributes = isfile(caf) ?
        load(caf, "cloud_attributes") :
        Dict{Symbol, Any}()

    cloud_attributes[:_folder] = folder
    PointCloud(point_attributes, cloud_attributes)
end

"""
    sync!(::PointCloud)

Force synchronization of all properties of a memory-mapped PointCloud. It also causes cloud
attributes to be saved.
"""
function sync!(cloud::PointCloud)
    @assert haskey(cloud.cloud_attributes, :_folder) "To sync! a cloud it has to be a mapped one"
    for a in values(cloud.point_attributes)
        sync!(a)
    end

    folder = cloud.cloud_attributes[:_folder]

    cloud_attributes = delete!(copy(cloud.cloud_attributes), :_folder)

    save(cloud_attributes_file(folder), "cloud_attributes", cloud_attributes)
    cloud
end

"""
    resize!(::CloudFolder, new_size::Int)

Resizes the binary files of the CloudFolder to allow storage of `new_size` points.
"""
function Base.resize!(folder::CloudFolder, new_size::Int)
    attrs = read_attribute_types(point_attributes_file(folder))
    for (name, type) in attrs
        filename = joinpath(folder.path, "$(name).bin")
        new_filesize = sizeof(type) * new_size
        open(filename; read = true, write = true) do f
            truncate(f, new_filesize)
        end
    end
    folder
end

"""
    CloudFolder(path::String, init::PointCloud)

Initializes a `CloudFolder` at the given `path` with the point and cloud attributes from
`init`. A format that is suitable for out-of-core work on point clouds using memory mapping
of flat binary files.
"""
function CloudFolder(path::String, init::PointCloud)
    folder = CloudFolder(path)
    n_points = length(init)

    for (k,v) in init.point_attributes
        add_point_attribute(folder, k => eltype(v))
    end

    resize!(folder, n_points)
    cloud = mmap(folder)
    for (k,v) in init.point_attributes
        cloud[k] .= v
    end
    merge!(cloud.cloud_attributes, init.cloud_attributes)
    sync!(cloud)

    folder
end
