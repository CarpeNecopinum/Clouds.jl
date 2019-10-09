struct AOSVector{T,D} <: AbstractVector{T}
    ptr::Ptr{UInt8}
    len::UInt64
end

Base.size(A::AOSVector) = (A.len,)
Base.length(A::AOSVector) = A.len
Base.checkbounds(A::AOSVector, i) = i <= A.len ? nothing : throw(BoundsError(A,i))

function Base.setindex!(A::AOSVector{T,D}, v, i) where {T,D}
    @boundscheck checkbounds(A, i)
    unsafe_store!(Ptr{T}(A.ptr + (i - 1) * D), v)
    A[i]
end

function Base.getindex(A::AOSVector{T,D}, i) where {T,D}
    @boundscheck checkbounds(A, i)
    unsafe_load(Ptr{T}(A.ptr + (i - 1) * D))
end

Base.getindex(A::AOSVector, i::CartesianIndex) = A[i[1]]
Base.setindex!(A::AOSVector, v, i::CartesianIndex) = (A[i[1]] = v)

function Base.iterate(A::AOSVector{T,D}, state = 1) where {T,D}
    if state > A.len
        nothing
    else
        (A[state], state+1)
    end
end
