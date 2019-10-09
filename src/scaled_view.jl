struct ScaledView{T, S} <: AbstractVector{S}
    data::T
    scale::S
    shift::S
end

#ScaledView(data::T, scale::S, shift::S) where {T,S} = ScaledView{T, S}(data, scale, shift)

Base.size(A::ScaledView) = size(A.data)
Base.getindex(A::ScaledView, i) = (A.data[i] * A.scale) + A.shift
Base.setindex!(A::ScaledView, v, i) = (A.data[i] = round(eltype(A.data), (v - A.shift) / A.scale))

function Base.iterate(A::ScaledView, state = ())
    inner = iterate(A.data, state...)
    isnothing(inner) && return nothing
    (inner[1] * A.scale + A.shift, inner[2])
end

Base.length(A::ScaledView) = length(A.data)
