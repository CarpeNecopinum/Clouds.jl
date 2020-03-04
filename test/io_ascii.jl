@testset "ASCII / XYZ IO" begin


    @testset "Load/Save via filename" begin
        mktemp() do filename, _
            cloud = PointCloud(; positions = rand(Vec3f0, 100))
            Clouds.saveASCII(filename, cloud.positions)

            cloud_load = Clouds.loadASCII(filename; positions = Vec3f0)
            @test cloud_load.positions == cloud.positions

            (cloud_positions,) = Clouds.loadASCII(filename, Vec3f0)
            @test cloud_positions == cloud.positions
        end
    end

    @testset "Load/Save via IO" begin
        mktemp() do _, io
            cloud = PointCloud(; positions = rand(Vec3f0, 100))
            Clouds.saveASCII(io, cloud.positions)

            seek(io, 0)
            cloud_load = Clouds.loadASCII(io; positions = Vec3f0)
            @test cloud_load.positions == cloud.positions

            seek(io, 0)
            (cloud_positions,) = Clouds.loadASCII(io, Vec3f0)
            @test cloud_positions == cloud.positions
        end
    end

    @testset "Multiple Attributes" begin
        mktemp() do filename, _
            cloud = PointCloud(; positions = rand(Vec3f0, 100), niceness = rand(Float32, 100))

            Clouds.saveASCII(filename, cloud.positions, cloud.niceness)

            cloud_load = Clouds.loadASCII(filename; positions = Vec3f0, niceness = Float32)
            @test cloud_load.positions == cloud.positions
            @test cloud_load.niceness == cloud.niceness

            (cloud_positions, cloud_niceness) = Clouds.loadASCII(filename, Vec3f0, Float32)
            @test cloud_positions == cloud.positions
            @test cloud_niceness == cloud.niceness
        end
    end
end
