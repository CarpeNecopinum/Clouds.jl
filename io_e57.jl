struct E57Header
    fileSignature::NTuple{8,UInt8}
    majorVersion::UInt32
    minorVersion::UInt32
    filePhysicalLength::UInt64
    xmlPhysicalOffset::UInt64
    xmlLogicalLength::UInt64
    pageSize::UInt64
    E57Header() = new()
end

struct DataPacketHeader
    packetType::UInt8
    packetFlags::UInt8
    packetLogicalLengthMinus1::UInt16
    bytestreamCount::UInt16
end

struct CompressedVectorSectionHeader
    sectionid::UInt8
    reserved::StaticArrays.SVector{7,UInt8}
    sectionLogicalLength::UInt64
    dataPhysicalOffset::UInt64
    indexPhysicalOffset::UInt64
end

e57physicalOffset(logical::Integer, page_size = 1024) = logical + 4 * (logical ÷ (page_size - 4))
e57logicalOffset(physical::Integer, page_size = 1024) = physical - 4 * (physical ÷ page_size)

struct E57Depager{IO} <: Base.IO
    io::IO
end

function Base.read(dp::E57Depager, ::Type{UInt8})
    p = position(dp.io)
    in_page = p % 1024
    in_page < 1020 || skip(dp.io, 1024 - in_page)
    read(dp.io, UInt8)
end

function Base.unsafe_read(dp::E57Depager, ptr::Ptr{UInt8}, n::UInt)
    p = position(dp.io)
    in_page = p % 1024
    if in_page > 1024
        skip(dp.io, 1024 - in_page)
        in_page = 0
    end
    rest = 1020 - in_page
    offset = 0
    while n > 0
        nbytes = min(n, rest)
        unsafe_read(dp.io, ptr + offset, nbytes)
        n -= nbytes
        offset += nbytes
        n == 0 || skip(dp.io, 4)
        rest = 1020
    end
end

function Base.skip(dp::E57Depager, delta)
    p = position(dp.io)
    offset = e57logicalOffset(p)
    offset += delta
    seek(dp.io, e57physicalOffset(offset))
end

function extract(::Type{Quaternion}, e::LightXML.XMLElement)
    Quaternion(parse.(Float64, LightXML.content.((e["w"][1], e["x"][1], e["y"][1], e["z"][1])))...)
end
function extract(::Type{Vec3{T}}, e::LightXML.XMLElement) where {T}
    Vec3(parse.(T, LightXML.content.((e["x"][1], e["y"][1], e["z"][1]))))
end

function pose_to_mat4(e::LightXML.XMLElement)
    result = zero(StaticArrays.MMatrix{4,4,Float64})
    result[1:3,1:3] .= Quaternions.rotationmatrix(extract(Quaternion, e["rotation"][1]))
    result[1:3,4] .= extract(Vec3f0, e["translation"][1])
    result[4,4] = 1.0
    SMatrix(result)
end

function parse_prototype(e::LightXML.XMLElement)
    result = Vector{Pair{String,Type}}()
    for c in LightXML.child_elements(e)
        name, type = LightXML.name(c), LightXML.attribute(c, "type")
        if type == "Float"
            prec = LightXML.attribute(c, "precision")
            push!(result, name => (prec == "single" ? Float32 : Float64))
        elseif type == "Integer"
            maxval = parse(Int64, LightXML.attribute(c, "maximum"))
            push!(result, name => (UInt8, UInt16, UInt32, UInt32, UInt64, UInt64, UInt64, UInt64)[ceil(Int, log(256, maxval+1))])
        end
    end
    result
end

function compress_struc!(struc::Vector{Pair{String,Type}})
    for (i,x) in enumerate(struc)
        if x[1][end] == 'X'
            new_name = x[1][1:end-1]
            @assert struc[i+1][1] == new_name * "Y"
            @assert struc[i+2][1] == new_name * "Z"

            struc[i] = new_name => GeometryTypes.Vec3{x[2]}
            deleteat!(struc, i+2)
            deleteat!(struc, i+1)
        elseif x[1][end-2:end] == "Red"
            new_name = x[1][1:end-3]
            @assert struc[i+1][1] == new_name * "Green"
            @assert struc[i+2][1] == new_name * "Blue"

            struc[i] = new_name => GeometryTypes.Vec3{x[2]}
            deleteat!(struc, i+2)
            deleteat!(struc, i+1)
        end
    end
    struc
end

function read_strided!(arr::AbstractArray{T}, dp::E57Depager, stride) where {T}
    for i in LinearIndices(arr)
        arr[i] = read(dp, T)
        skip(dp, stride - sizeof(T))
    end
end

function copy_out!(source::AbstractArray, target::AbstractArray, index::Integer)
    for i in LinearIndices(target)
        target[i] = source[i][index]
    end
end

function interleave!(result::AbstractArray, a, b, c)
    for i in LinearIndices(result)
        result[i] = eltype(result)(a[i], b[i], c[i])
    end
    result
end

function postprocess_cloud!(cloud::PointCloud)
    if all(haskey.(Ref(cloud), [:cartesianX, :cartesianY, :cartesianZ]))
        type = eltype(cloud[:cartesianX])
        x = cloud[:cartesianX]::Vector{type}
        y = cloud[:cartesianY]::Vector{type}
        z = cloud[:cartesianZ]::Vector{type}
        interleave!(cloud.positions, x, y, z)
        delete!(cloud, :cartesianX)
        delete!(cloud, :cartesianY)
        delete!(cloud, :cartesianZ)
    end
    if all(haskey.(Ref(cloud), [:colorRed, :colorGreen, :colorBlue]))
        type = eltype(cloud[:colorRed])
        r = cloud[:colorRed]::Vector{type}
        g = cloud[:colorGreen]::Vector{type}
        b = cloud[:colorBlue]::Vector{type}
        cloud[:color] = interleave!(Array{Vec3{type}}(undef, length(r)), r, g, b)
        delete!(cloud, :colorRed)
        delete!(cloud, :colorGreen)
        delete!(cloud, :colorBlue)
    end
    cloud
end


function read_e57_cloud(points::LightXML.XMLElement, dp::E57Depager)
    struc = parse_prototype(points["prototype"][1])
    global laststruc = struc

    result = PointCloud()
    for (name, type) in struc
        name == "cartesian" && continue
        result[Symbol(name)] = Vector{type}()
    end
    resize!(result, parse(Int, LightXML.attribute(points, "recordCount")))

    block_offset = parse(Int, LightXML.attribute(points, "fileOffset"))
    seek(dp.io, block_offset)

    println("    Loading point data")

    streams = map(x->result[Symbol(x[1])], struc)
    bytesoffsets = zeros(UInt64, axes(streams))

    cvsh = read!(dp, Ref{CompressedVectorSectionHeader}())[]
    seek(dp.io, cvsh.dataPhysicalOffset)

    while any(bytesoffsets .< sizeof.(streams))
        head = read!(dp, Ref{DataPacketHeader}())[]
        @assert head.packetType == 0x01
        @assert head.bytestreamCount == length(streams)
        portionLengths = read!(dp, Vector{UInt16}(undef, length(streams)))

        for i in LinearIndices(streams)
            unsafe_read(dp, pointer(streams[i]) + bytesoffsets[i], portionLengths[i])
            bytesoffsets[i] += portionLengths[i]
        end
    end
    result
end

function loadE57(filename::AbstractString)
    dp = E57Depager(open(filename))
    seek(dp.io, 0)

    h = read!(dp, Ref(E57Header()))[]
    seek(dp.io, h.xmlPhysicalOffset)

    xml = String(read!(dp, Vector{UInt8}(undef, h.xmlLogicalLength)))
    doc = LightXML.parse_string(xml)
    root = LightXML.root(doc)

    scans = root["data3D"][1]["vectorChild"]

    counter = 1
    map(scans) do scan
        println("Loading scan $(counter) / $(length(scans))")
        counter += 1
        cloud = read_e57_cloud(scan["points"][1], dp)
        println("    Interleaving")
        postprocess_cloud!(cloud), pose_to_mat4(scan["pose"][1])
    end
end
