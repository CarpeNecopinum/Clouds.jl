module Clouds
    using NearestNeighbors
    const NN = NearestNeighbors

    import LightXML
    import StaticArrays
    import GeometryTypes
    import Quaternions
    using ProgressMeter
    using LinearAlgebra
    using GeometryTypes
    using Quaternions: Quaternion
    using Base.Threads
    using ColorTypes
    using Statistics: mean
    using FixedPointNumbers: N0f8, N0f16
    using Mmap: mmap

    using ProgressMeter: @showprogress

    const Vec3e0 = GeometryTypes.Vec3{Float64}

    import CodecZlib

    include("cloud.jl")
    include("utils.jl")

    include("aos_vector.jl")
    include("scaled_view.jl")

    include("io_pts.jl")
    include("io_e57.jl")
    include("io_pbrbin.jl")
    include("io_vrsplats.jl")
    include("io_pbrjl.jl")
    include("io_las.jl")
    include("io_ascii.jl")
    include("io_cloudfolder.jl")

    include("combine.jl")

    export PointCloud,
        loadPBRBIN,
        loadPTS,
        saveVRSplats,
        compute_radii,
        loadE57,
        compute_normals,
        add_point_attribute,
        add_cloud_attribute,
        CloudFolder,
        KeepFirstGridFilter
end
