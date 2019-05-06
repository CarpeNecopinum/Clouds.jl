using Statistics: mean

function compute_radii(cloud; min_neighbors = 6, factor = 1.0)
    cloud[:radius] = radii = Vector{Float32}(undef, length(cloud))
    for i in 1:1024:length(cloud)
        dists = NN.knn(cloud.spatial_index, cloud.positions[i:min(i+1024,end)], min_neighbors + 1, true)[2]
        radii[i:min(i+1024,end)] = map(x -> x[end] * factor, dists)
    end
    radii
end

function fit_normal(pts::AbstractArray{Vec3f0})
    com = mean(pts)
    cov = sum((x.-com) * (x-com)' for x in pts)
    eig = eigen(cov)
    eig.vectors[:,1]
end

function refine_normal(pts::AbstractArray{Vec3f0}, guess::Vec3f0)
    n = fit_normal(pts)
    (guess ⋅ n) > 0 ? n : -n
end


function compute_normals(cloud::PointCloud; n_neighbors = 6)
    if cloud.spatial_index == nothing
        print("Building KD-Tree... ")
        cloud = PointCloud(cloud.positions, cloud.attributes)
        println("done.")
    end

    cloud[:normal] = normals = Vector{Vec3f0}(undef, length(cloud))
    pos = cloud.positions

    for i in 1:1024:length(cloud)
        idcs = NN.knn(cloud.spatial_index, cloud.positions[i:min(i+1024,end)], n_neighbors + 1, true)[1]
        normals[i:min(i+1024,end)] = map(x -> fit_normal(pos[x]), idcs)
    end
    normals
end

function refine_normals!(cloud::PointCloud; n_neighbors = 6)
    if cloud.spatial_index == nothing
        print("Building KD-Tree... ")
        cloud = PointCloud(cloud.positions, cloud.attributes)
        println("done.")
    end

    normals = cloud[:normal]::Vector{Vec3f0}
    pos = cloud.positions

    @threads for i in 1:1024:length(cloud)
        idcs = NN.knn(cloud.spatial_index, cloud.positions[i:min(i+1024,end)], n_neighbors + 1, true)[1]
        normals[i:min(i+1024,end)] = map(x -> refine_normal(pos[x[2]], normals[x[1]]), enumerate(idcs))
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
