@testset "Grid Filtering" begin
    x = PointCloud(; positions = rand(Vec3f0, 300))
    y = PointCloud(; positions = rand(Vec3f0, 300))

    filt = KeepFirstGridFilter(0.1)
    append!(filt, x)
    append!(filt, y)

    @test length(filt.cloud) <= (length(x) + length(y))
    @test length(filt.full_cells) == length(filt.cloud)

    filt2 = KeepFirstGridFilter(0.1)
    insert!(filt2, x.positions, x)
    insert!(filt2, y.positions, y)

    @test filt2.cloud.positions == filt.cloud.positions
end
