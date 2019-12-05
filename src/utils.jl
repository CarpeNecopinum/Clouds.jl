using Statistics: mean

function compute_radii(cloud; min_neighbors = 6, factor = 1.0)
    cloud[:radius] = radii = Vector{Float32}(undef, length(cloud))
    for i in 1:1024:length(cloud)
        dists = NN.knn(cloud.spatial_index, cloud.positions[i:min(i+1024,end)], min_neighbors + 1, true)[2]
        radii[i:min(i+1024,end)] = map(x -> x[end] * factor, dists)
    end
    radii
end

function fit_normal(pts::AbstractArray)
    com = mean(pts)
    cov = sum((x.-com) * (x-com)' for x in pts)
    eig = eigen(cov)
    eig.vectors[:,argmin(eig.values)]
end

function refine_normal(pts::AbstractArray, guess)
    n = fit_normal(pts)
    (guess ⋅ n) > 0 ? n : -n
end

function compute_normals_radius!(points::AbstractVector, normals::AbstractVector, tree, radius::Real)
    @threads for i in 1:length(points)
        idcs = NN.inrange(tree, points[i], radius, false)
        normals[i] = fit_normal(@view points[idcs])
    end
    normals
end

compute_normals_radius(cloud::PointCloud, radius::Real) =
    compute_normals_radius!(positions(cloud), similar(positions(cloud)), tree(cloud), radius)
compute_normals_radius(points::AbstractVector, tree, radius::Real) =
    compute_normals_radius!(points, similar(points), tree, radius)

function compute_normals(cloud::PointCloud; n_neighbors = 6)
    @assert cloud.spatial_index != nothing

    cloud[:normal] = normals = Vector{Vec3f0}(undef, length(cloud))
    pos = cloud.positions

    Threads.@threads for i in 1:64:length(cloud)
        idcs = NN.knn(cloud.spatial_index, cloud.positions[i:min(i+64,end)], n_neighbors + 1, true)[1]
        normals[i:min(i+64,end)] .= idcs .|> (x -> fit_normal(pos[x]))
    end
    normals
end

function refine_normals!(cloud::PointCloud; n_neighbors = 6)
    @assert cloud.spatial_index != nothing

    normals = cloud[:normal]::Vector{Vec3f0}
    pos = cloud.positions

    Threads.@threads for i in 1:length(cloud)
        idcs = NN.knn(cloud.spatial_index, cloud.positions[i], n_neighbors + 1, false)[1]
        normals[i] = refine_normal(pos[idcs], normals[i])
    end
    normals
end


function transform_points!(vecs::AbstractArray, tx::Mat4)
    rss = StaticArrays.SMatrix{3,3}(tx[1:3,1:3])
    shift = StaticArrays.SVector{3}(tx[1:3,4])

    for i in LinearIndices(vecs)
        vecs[i] = rss * vecs[i] + shift
    end
end

function transform_vectors!(vecs::AbstractArray, tx::Mat4)
    rss = StaticArrays.SMatrix{3,3}(tx[1:3,1:3])
    for i in LinearIndices(vecs)
        vecs[i] = rss * vecs[i]
    end
end

function transform!(cloud::PointCloud, tx::AbstractMatrix)
    transform_points!(cloud.positions, tx)
    transform_vectors!(cloud[:normal], tx)
    cloud
end

function make_normals_consistent!(cloud::PointCloud, n_neighbors = 16)
    @assert cloud.spatial_index != nothing "Cloud needs a NN acceleration structure"
    @assert haskey(cloud, :normal) "Cloud needs to have some normals already"

    normals = cloud[:normal]::Vector{Vec3f0}
    pos = cloud.positions

    flips = 0
    @showprogress "Making normals consistent " for i in 1:length(cloud)
        idcs, dists = NN.knn(cloud.spatial_index, cloud.positions[i], n_neighbors + 1, false)
        σ2 = (1.5f0 * dists[end]) ^ 2

        avg = mean(normals[pi] * exp(-dists[j]^2 / (2σ2)) for (j,pi) in enumerate(idcs))

        if normals[i] ⋅ avg < 0
            normals[i] = -normals[i]
            flips += 1
        end
    end
    println("Number of flipped normals: $(flips)")
end

function read_packed(::Type{T}, io::IO) where {T}
    datas = Any[]
    for t in fieldtypes(T)
        push!(datas, read(io, t))
    end
    T(datas...)
end

function grid_filter(points::Vector{Vec3f0}, edge_len::Float32)
    cells = Dict{Vec3{Int32}, Tuple{Vec3f0,Float32}}()
    @showprogress "Sorting into grid... " for i in eachindex(points)
        p = points[i]
        key = round.(Int32, p ./ edge_len)
        cell = get!(() -> (Vec3f0(0),0f0), cells, key)
        cells[key] = (cell[1] + p, cell[2] + 1f0)
    end

    [x[1] ./ x[2] for x in values(cells)]
end
