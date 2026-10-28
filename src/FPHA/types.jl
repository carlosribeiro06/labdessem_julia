abstract type TailraceModel end

Base.@kwdef struct ConstantTailrace <: TailraceModel
    level_m::Float64
end

Base.@kwdef struct PolynomialTailrace <: TailraceModel
    coefficients::NTuple{5,Float64}
end

function evaluate(model::ConstantTailrace, ::Float64)::Float64
    model.level_m
end

function evaluate(model::PolynomialTailrace, outflow_m3s::Float64)::Float64
    c = model.coefficients
    q = outflow_m3s
    @inbounds c[1] + q * (c[2] + q * (c[3] + q * (c[4] + q * c[5])))
end

Base.@kwdef struct FittingBounds
    v_min::Float64
    v_max::Float64
    n_volume_points::Int = 10
    n_flow_points::Int = 10
    n_spillage_points::Int = 2
    max_planes_per_hydro::Int = 15
    single_volume::Bool = false
end

function validate(bounds::FittingBounds)::Bool
    bounds.v_min < bounds.v_max &&
    bounds.n_volume_points >= 2 &&
    bounds.n_flow_points >= 2 &&
    bounds.n_spillage_points >= 1 &&
    bounds.max_planes_per_hydro >= 1
end

Base.@kwdef struct RawPlane
    gamma_0::Float64
    gamma_v::Float64
    gamma_q::Float64
    gamma_s::Float64
end

function evaluate(plane::RawPlane, v::Float64, q::Float64, s::Float64)::Float64
    plane.gamma_0 + plane.gamma_v * v + plane.gamma_q * q + plane.gamma_s * s
end

function Base.isapprox(a::RawPlane, b::RawPlane; kwargs...)
    isapprox(a.gamma_0, b.gamma_0; kwargs...) &&
    isapprox(a.gamma_v, b.gamma_v; kwargs...) &&
    isapprox(a.gamma_q, b.gamma_q; kwargs...) &&
    isapprox(a.gamma_s, b.gamma_s; kwargs...)
end
