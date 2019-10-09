struct LASCommonHeader
    file_signature::Vec{4,UInt8}
    file_source_id::UInt16
    global_encoding::UInt16
    project_id_guid_data_1::UInt32
    project_id_guid_data_2::UInt16
    project_id_guid_data_3::UInt16
    project_id_guid_data_4::Vec{8,UInt8}
    version_major::UInt8
    version_minor::UInt8
end

struct LAS12HeaderTail
    system_identifier::Vec{32,UInt8}
    generating_software::Vec{32,UInt8}
    file_creation_day_of_year::UInt16
    file_creation_year::UInt16
    header_size::UInt16
    offset_to_point_data::UInt32
    number_of_variable_length_records::UInt32
    point_data_record_format::UInt8
    point_data_record_length::UInt16
    number_of_point_records::UInt32
    number_of_points_by_return::Vec{5,UInt32}
    x_scale_factor::Float64
    y_scale_factor::Float64
    z_scale_factor::Float64
    x_offset::Float64
    y_offset::Float64
    z_offset::Float64
    max_x::Float64
    min_x::Float64
    max_y::Float64
    min_y::Float64
    max_z::Float64
    min_z::Float64
end

function readPointDataRecordFormat3(io, header, tail, ::Val{props}) where {props}
    positions = Vector{Vec3f0}(undef, tail.number_of_point_records)
    intensities = (:intensity ∈ props) ? Vector{N0f16}() : nothing
    classifications = (:classification ∈ props) ? Vector{UInt8}() : nothing
    user_data = (:user_data ∈ props) ? Vector{UInt8}() : nothing
    point_source_id = (:point_source_id ∈ props) ? Vector{UInt16}() : nothing

    scale = Vec3e0(tail.x_scale_factor, tail.y_scale_factor, tail.z_scale_factor)
    offset = Vec3e0(tail.x_offset, tail.y_offset, tail.z_offset)

    Threads.@threads for i in 1:tail.number_of_point_records
        record_offset = tail.offset_to_point_data + (i-1) * tail.point_data_record_length
        seek(io, record_offset)

        pos = read(io, Vec3{Int32})
        positions[i] = pos .* scale .+ offset

        if !isnothing(intensities)
            intensities[i] = read(io, UInt16)
        end

        if !isnothing(classifications)
            seek(io, record_offset + 15)
            classifications[i] = read(io, UInt8)
        end

        if !isnothing(user_data)
            seek(io, record_offset + 17)
            user_data[i] = read(io, UInt8)
        end

        if !isnothing(point_source_id)
            seek(io, record_offset + 18)
            point_source_id[i] = read(io, UInt16)
        end
    end

    props_dict = Dict{Symbol, Vector}()
    isnothing(intensities) || (props_dict[:intensity] = intensities)
    isnothing(classifications) || (props_dict[:classification] = classifications)
    isnothing(user_data) || (props_dict[:user_data] = user_data)
    isnothing(point_source_id) || (props_dict[:point_source_id] = point_source_id)

    PointCloud(positions, props_dict)
end

function loadLAS(filename::AbstractString, props = [:intensity, :user_data, :point_source_id, :classification])
    open(filename) do f
        header = read_packed(LASCommonHeader, f)
        v = (header.version_major, header.version_minor)
        tail = if v == (1,2)
            read_packed(LAS12HeaderTail, f)
        else
            throw(ErrorException("LAS Version $(v) not implemented"))
        end
        seek(f, tail.offset_to_point_data)

        if (tail.point_data_record_format == 3)
            readPointDataRecordFormat3(f, header, tail, Val(Tuple(props)))
        end
    end
end

function mmapPointDataRecordFormat3(x, header, las_12)
    seek(x, las_12.offset_to_point_data)
    point_data = mmap(x)
    max_len = length(point_data) ÷ 34
    if (las_12.number_of_point_records > max_len)
        @warn "LAS File says it has $(las_12.number_of_point_records) records, but only large enough for $(max_len)"
    end
    n_points = min(max_len, las_12.number_of_point_records)
    las = (
        x = ScaledView(
                AOSVector{Int32,34}(pointer(point_data), n_points),
                las_12.x_scale_factor, las_12.x_offset),
        y =  ScaledView(
                AOSVector{Int32,34}(pointer(point_data) + 4, n_points),
                las_12.y_scale_factor, las_12.y_offset),
        z =  ScaledView(
                AOSVector{Int32,34}(pointer(point_data) + 8, n_points),
                las_12.z_scale_factor, las_12.z_offset),
        src_id = AOSVector{UInt16,34}(pointer(point_data) + 18, n_points),
        r = ScaledView(
                AOSVector{UInt16,34}(pointer(point_data) + 28, n_points),
                1f0 / typemax(UInt16), 0f0),
        g =  ScaledView(
                AOSVector{UInt16,34}(pointer(point_data) + 30, n_points),
                1f0 / typemax(UInt16), 0f0),
        b =  ScaledView(
                AOSVector{UInt16,34}(pointer(point_data) + 32, n_points),
                1f0 / typemax(UInt16), 0f0),
    )
    (point_data, las)
end

function mapLAS(f::IOStream)
    header = read_packed(LASCommonHeader, f)
    v = (header.version_major, header.version_minor)
    tail = if v == (1,2)
        read_packed(LAS12HeaderTail, f)
    else
        throw(ErrorException("LAS Version $(v) not implemented"))
    end
    seek(f, tail.offset_to_point_data)

    if (tail.point_data_record_format == 3)
        mmapPointDataRecordFormat3(f, header, tail)
    end
end

function mapLAS(filename::AbstractString)
    open(mapLAS, filename)
end

function resizeLAS(filename::AbstractString, new_size::Size)
    open(filename) do f
        header = read_packed(LASCommonHeader, f)
        v = (header.version_major, header.version_minor)
        tail = if v == (1,2)
            read_packed(LAS12HeaderTail, f)
        else
            throw(ErrorException("LAS Version $(v) not implemented"))
        end
        seek(f, tail.offset_to_point_data)

        if (tail.point_data_record_format == 3)
            mmapPointDataRecordFormat3(f, header, tail)
        end
    end

end

using PyCall

function loadLASPy(filename::AbstractString)
    laspy = pyimport("laspy")
    lasfile = laspy.file.File(filename)

    println("Loading positions ...")
    positions = Vec3f0.(zip(lasfile.x, lasfile.y, lasfile.z))

    py"""
        from gc import collect
        from numpy import array
        """

    print("Loading colors...")
    color = begin
        red = py"array($lasfile.red)"
        py"collect()"
        green = py"array($lasfile.green)"
        py"collect()"
        blue = py"array($lasfile.blue)"
        py"collect()"

        Vec3f0.(zip(red, green, blue)) / Float32(typemax(eltype(red)))
    end
    println(" done.")

    PointCloud(positions; color = color)
end
