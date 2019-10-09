function loadPTS(filename::AbstractString)
    result = PointCloud()
    result[:color] = color = Vector{Vec3f0}()
    open(filename, "r") do f
        len = parse(Int, readline(f))
        resize!(result, len)
        for i in 1:len
            snips = split(readline(f))
            x,y,z,r,g,b = parse.(Float32, snips)
            result.positions[i] = Vec3f0(x,y,z)
            color[i] = Vec3f0(r,g,b) ./ 255.0
        end
    end
    result
end

function savePTS(position::Vector{Vec3f0}, color::Vector, filename::AbstractString)
    @assert length(position) == length(color)
    norm = (maximum(maximum(color)) < 1)

    open(filename, "w") do f
        println(f, length(position))
        for i in 1:length(position)
            x = position[i]
            c = norm ? round.(Int, color[i] .* 255f0) : round.(Int, color[i])
            println(f, x[1], " ", x[2], " ", x[3], " ", c[1], " ", c[2], " ", c[3])
        end
    end
end

function savePTSNormals(position::Vector{Vec3f0}, normals::Vector{Vec3f0}, clusters::Vector, filename::AbstractString)
    @assert length(position) == length(color)

    open(filename, "w") do f
        println(f, length(position))
        for i in 1:length(position)
            x = position[i]
            ci = clusters[i]
            n = normals[i]
            println(f, x[1], " ", x[2], " ", x[3], " ", ci, " ", n[1], " ", n[2], " ", n[3])
        end
    end
end

function savePTS(position::Vector{Vec3f0}, color::Vector, clusters::Vector, filename::AbstractString)
    @assert length(position) == length(color)
    norm = (maximum(maximum(color)) < 1)

    open(filename, "w") do f
        println(f, length(position))
        for i in 1:length(position)
            x = position[i]
            ci = clusters[i]
            c = norm ? round.(Int, color[i] .* 255f0) : round.(Int, color[i])
            println(f, x[1], " ", x[2], " ", x[3], " ", ci, " ", c[1], " ", c[2], " ", c[3])
        end
    end
end

function savePTS(cloud::PointCloud, filename::AbstractString)
    savePTS(cloud.positions, cloud[:color], filename::AbstractString)
end
