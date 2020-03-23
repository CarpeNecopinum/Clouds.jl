# Clouds.jl

Point clouds with support for per-cloud and per-point attributes. Including IO from/to several formats and some simple processing (grid filter based combination, normal estimation).


## Basic Usage

```julia
using Clouds
using GeometryTypes: Vec3f0

# Make a point cloud with 100 random positions
# point-attributes can be passed as keyword-arguments to the constructor
cloud = PointCloud(; positions = rand(Vec3f0, 100))

# new point-attributes can be added using the dot-syntax
cloud.normals = normalize.(randn(Vec3f0, 100))

# the dot-syntax checks that you don't add attributes of wrong size:

cloud.fail = randn(99)
> ERROR: AssertionError: Cannot set point attribute normals: PointCloud has size 100, but the new attribute has size 99

# access cloud attributes with square brackets:

cloud[:name] = "Hello Cloud!"

```
