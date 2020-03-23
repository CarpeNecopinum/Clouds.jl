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

## Hint(s):

When writing functions that work on `PointCloud`s, don't take a `PointCloud` instance directly.
Instead pass each attribute as an individual parameter, so you get a type stable function.
For convenience you can then add a method that takes the `PointCloud` and passes the relevant attributes to the other method.

```julia

function bad_func(cloud::PointCloud)
    accum = Vec3f0(0.0)
    for i in eachindex(cloud.positions)
        # bad: the type of cloud.positions is not stable here (large overhead)
        accum .+= cloud.positions[i]
    end
    accum ./ Ref(length(cloud))
end

function better_func(positions::Vector)
    # better: the type of positions is known here
    # work with positions here
end

# optional: triggers a single dynamic dispatch of better_func
# but inside the called method, `positions` is stable again
better_func(cloud::PointCloud) = better_func(cloud.positions)
```
(Mind that for something like computing the center of mass, which `bad_func` attempts to do, `Statistics.mean` will do just fine.)

`bad_func` will trigger a lot of dynamic dispatch, so it'll be slow and probably allocate a lot.
`better_func` will be specialized on the type of the `positions` array passed in, so it'll be type stable.

Most methods in this package will follow the pattern of `better_func`.
