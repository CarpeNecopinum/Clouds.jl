module Clouds
    using NearestNeighbors
    const NN = NearestNeighbors

    import LightXML
    import StaticArrays
    import GeometryTypes
    import Quaternions
    using ProgressMeter
    using LinearAlgebra
    using GeometryTypes: Vec, Mat
    using Quaternions: Quaternion
    using Base.Threads

    const Point = GeometryTypes.Point
    const Point3 = GeometryTypes.Point3
    const Vec3 = GeometryTypes.Vec3
    const Vec4 = GeometryTypes.Vec4
    const Mat4 = GeometryTypes.Mat4

    include("cloud.jl")
    include("io_pts.jl")
    include("io_e57.jl")
    include("io_pbrbin.jl")
    include("io_vrsplats.jl")

    include("utils.jl")

    export PointCloud,
        loadPBRBIN,
        loadPTS,
        saveVRSplats,
        compute_radii,
        loadE57
end
