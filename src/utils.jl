using Statistics: mean, cov


"""
    compute_radii!(radii, positions, tree; min_neighbors = 6, factor = 1.0)

For each point in `positions` find the minimal radius required to include all
`min_neighbors` closest neighbors of that point and multiply it with `factor`.

The default values are reasonable defaults for radii to render a point cloud as circular
disks with the computed radius.
"""
function compute_radii!(radii, positions, tree; min_neighbors = 6, factor = 1.0)
    @threads for i in eachindex(radii)
        dists = NN.knn(tree, positions[i], min_neighbors + 1, true)[2]
        radii[i] = dists[end] * factor
    end
    radii
end

"""
    fit_normal(points)

Compute the normal of the least-squares plane through `points` to obtain an unoriented
normal.
"""
function fit_normal(points)
    com = mean(points)
    cova = (sum(Float64.((x-com) * (x-com)') for x in points))
    eltype(points)(eigen(Hermitian(cova)).vectors[:,1])
end

"""
    refine_normal(points, guess)

Compute a normal analogous to `fit_normal(points)`, but maintains the orientation from
`guess` (i.e. the dot product of the result and `guess` will be non-negative).

"""
function refine_normal(points, guess)
    n = fit_normal(points)
    (guess ⋅ n) > 0 ? n : -n
end


"""
    compute_normals_radius!(points, normals, tree, radius)

Compute an unoriented normal for each point by fitting a plane through a neighborhood of
the given `radius` for each point.
"""
function compute_normals_radius!(points::AbstractVector, normals::AbstractVector, tree, radius::Real)
    @threads for i in 1:length(points)
        idcs = NN.inrange(tree, points[i], radius, false)
        normals[i] = fit_normal(@view points[idcs])
    end
    normals
end


"""
    compute_normals_knn!(points, normals, tree; n_neighbors = 6)

Compute an unoriented normal for each point by fitting a plane through the `n_neighbors`
closest neighbors
"""
function compute_normals_knn!(points, normals, tree; n_neighbors = 6)
    @threads for i in 1:length(points)
        idcs = NN.knn(tree, points[i], n_neighbors + 1)[1]
        normals[i] = fit_normal(points[idcs])
    end
    normals
end


"""
    refine_normals!(points, normals, tree; n_neighbors = 6)

Update the normals for each point by fitting a plane through the `n_neighbors`
closest neighbors and orient them such that they are consistent with the previous normal.
"""
function refine_normals!(points, normals, tree; n_neighbors = 6)
    Threads.@threads for i in 1:length(cloud)
        idcs = NN.knn(tree, points[i], n_neighbors + 1, false)[1]
        normals[i] = refine_normal(points[idcs], normals[i])
    end
    normals
end

"""
    transform_points!(points::AbstractArray, tx::Mat4)

Apply the rigid transformation `tx` onto `points`.
"""
function transform_points!(points::AbstractArray, tx::Mat4)
    rss = StaticArrays.SMatrix{3,3}(tx[1:3,1:3])
    shift = StaticArrays.SVector{3}(tx[1:3,4])

    for i in eachindex(points)
        points[i] = rss * points[i] + shift
    end
end

"""
    transform_vectors!(vecs::AbstractArray, tx::Mat4)

Apply the rigid transformation `tx` onto `vecs`. Since vectors have only a direction and
a length, not a position in space, the translational part of `tx` is ignored.
"""
function transform_vectors!(vecs::AbstractArray, tx::Mat4)
    rss = StaticArrays.SMatrix{3,3}(tx[1:3,1:3])
    for i in LinearIndices(vecs)
        vecs[i] = rss * vecs[i]
    end
end

"""
    make_normals_consistent!(positions, normals, tree; n_neighbors = 16)

Try to orient normals a bit more consistently by flipping the normals towards a weighted
average of their surrounding points.
"""
function make_normals_consistent!(positions, normals, tree; n_neighbors = 16)
    flips = 0
    @showprogress "Making normals consistent " for i in 1:length(cloud)
        idcs, dists = NN.knn(tree, positions[i], n_neighbors + 1, false)
        σ2 = (1.5f0 * dists[end]) ^ 2

        avg = mean(normals[pi] * exp(-dists[j]^2 / (2σ2)) for (j,pi) in enumerate(idcs))

        if normals[i] ⋅ avg < 0
            normals[i] = -normals[i]
            flips += 1
        end
    end
    println("Number of flipped normals: $(flips)")
end
