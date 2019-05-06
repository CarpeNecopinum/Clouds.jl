function loadPTS(filename::AbstractString)
    result = PointCloud{3,Float32,nothing}()
    open(filename, "r") do f
        readline(f)
        for ln in eachline(f)
            scan
        end
    end
end
