const GAMMA_V_EPS = 1e-6

function build_cloud(pf::ProductionFunction, bounds::FittingBounds)::Vector{NTuple{3,Float64}}
    grid = build_grid(bounds, pf.max_turbined_m3s)
    cloud = NTuple{3,Float64}[]
    sizehint!(cloud, length(grid.v_points) * length(grid.q_points))
    for v in grid.v_points
        for q in grid.q_points
            generation = evaluate_capped(pf, v, q, 0.0)
            push!(cloud, (v, q, generation))
        end
    end
    cloud
end

function fit_hull_planes(pf::ProductionFunction, bounds::FittingBounds)::Vector{RawPlane}
    cloud = build_cloud(pf, bounds)
    planes = convex_hull_upper_envelope(cloud, pf.hydro_name)

    isempty(planes) && throw(NoHyperplanesError(pf.hydro_name))

    if bounds.single_volume
        for i in eachindex(planes)
            if abs(planes[i].gamma_v) <= GAMMA_V_EPS
                planes[i] = RawPlane(
                    gamma_0=planes[i].gamma_0,
                    gamma_v=0.0,
                    gamma_q=planes[i].gamma_q,
                    gamma_s=0.0
                )
            end
        end
    end

    seen = Set{NTuple{3,UInt64}}()
    unique_planes = RawPlane[]
    for p in planes
        key = (reinterpret(UInt64, p.gamma_0), reinterpret(UInt64, p.gamma_v), reinterpret(UInt64, p.gamma_q))
        if key ∉ seen
            push!(seen, key)
            push!(unique_planes, p)
        end
    end

    unique_planes
end

function envelope_max(planes::Vector{RawPlane}, v::Float64, q::Float64)::Float64
    isempty(planes) && return -Inf
    maximum(evaluate(p, v, q, 0.0) for p in planes)
end

function envelope_min(planes::Vector{RawPlane}, v::Float64, q::Float64)::Float64
    isempty(planes) && return Inf
    minimum(evaluate(p, v, q, 0.0) for p in planes)
end

function compute_alpha_fpha(planes::Vector{RawPlane}, pf::ProductionFunction,
                            bounds::FittingBounds)::Float64
    isempty(planes) && return 1.0

    grid = build_grid(bounds, pf.max_turbined_m3s)

    sum_fpha0_fph = 0.0
    sum_fpha0_sq = 0.0

    for v in grid.v_points
        for q in grid.q_points
            fpha0 = envelope_min(planes, v, q)
            fph = evaluate_capped(pf, v, q, 0.0)
            sum_fpha0_fph += fpha0 * fph
            sum_fpha0_sq += fpha0 * fpha0
        end
    end

    sum_fpha0_sq == 0.0 ? 1.0 : sum_fpha0_fph / sum_fpha0_sq
end

function scale_plane_affine(plane::RawPlane, alpha::Float64)::RawPlane
    RawPlane(
        gamma_0=plane.gamma_0 * alpha,
        gamma_v=plane.gamma_v * alpha,
        gamma_q=plane.gamma_q * alpha,
        gamma_s=plane.gamma_s * alpha
    )
end

function scale_planes(planes::Vector{RawPlane}, alpha::Float64)::Vector{RawPlane}
    [scale_plane_affine(p, alpha) for p in planes]
end

const N_LATERAL_FLOW_SAMPLES = 9
const GAMMA_S_SNAP_EPS = 1e-10

function resolve_s_max(long_term_mean_inflow_m3s::Float64, max_turbined_m3s::Float64)::Float64
    long_term_mean_inflow_m3s > 0.0 ? 2.0 * long_term_mean_inflow_m3s : 2.0 * max_turbined_m3s
end

function representative_operating_point(
    plane::RawPlane, planes::Vector{RawPlane},
    pf::ProductionFunction, bounds::FittingBounds
)::Union{Nothing, Tuple{Float64, Float64}}
    grid = build_grid(bounds, pf.max_turbined_m3s)
    best::Union{Nothing, Tuple{Float64, Float64, Float64}} = nothing

    for v in grid.v_points
        for q in grid.q_points
            this_val = evaluate(plane, v, q, 0.0)
            min_val = minimum(evaluate(p, v, q, 0.0) for p in planes)
            if this_val - min_val <= 1e-8
                generation = evaluate(pf, v, q, 0.0)
                if best === nothing || generation > best[3]
                    best = (v, q, generation)
                end
            end
        end
    end

    best === nothing ? nothing : (best[1], best[2])
end

function fit_gamma_s(pf::ProductionFunction, v_rep::Float64, q_rep::Float64, s_max::Float64)::Float64
    s_max <= 0.0 && return 0.0

    sum_x = 0.0
    sum_y = 0.0
    for i in 0:(N_LATERAL_FLOW_SAMPLES - 1)
        lateral_flow = Float64(i) * s_max / Float64(N_LATERAL_FLOW_SAMPLES - 1)
        generation = evaluate(pf, v_rep, q_rep, lateral_flow)
        sum_x += lateral_flow
        sum_y += generation
    end

    n = Float64(N_LATERAL_FLOW_SAMPLES)
    mean_x = sum_x / n
    mean_y = sum_y / n

    cov = 0.0
    var_x = 0.0
    for i in 0:(N_LATERAL_FLOW_SAMPLES - 1)
        lateral_flow = Float64(i) * s_max / Float64(N_LATERAL_FLOW_SAMPLES - 1)
        generation = evaluate(pf, v_rep, q_rep, lateral_flow)
        dx = lateral_flow - mean_x
        cov += dx * (generation - mean_y)
        var_x += dx * dx
    end

    var_x == 0.0 && return 0.0
    slope = cov / var_x
    slope > -GAMMA_S_SNAP_EPS ? 0.0 : slope
end

function fit_gamma_s_for_planes!(
    planes::Vector{RawPlane}, pf::ProductionFunction,
    bounds::FittingBounds, long_term_mean_inflow_m3s::Float64
)
    s_max = resolve_s_max(long_term_mean_inflow_m3s, pf.max_turbined_m3s)
    snapshot = copy(planes)

    for i in eachindex(planes)
        rep = representative_operating_point(planes[i], snapshot, pf, bounds)
        gamma_s = if rep === nothing
            0.0
        else
            fit_gamma_s(pf, rep[1], rep[2], s_max)
        end
        planes[i] = RawPlane(
            gamma_0=planes[i].gamma_0,
            gamma_v=planes[i].gamma_v,
            gamma_q=planes[i].gamma_q,
            gamma_s=gamma_s
        )
    end
end

const ORIGIN_EPS = 1e-9

function plane_normal(plane::RawPlane)::NTuple{3,Float64}
    (plane.gamma_v, plane.gamma_q, -1.0)
end

function angle_deg(a::RawPlane, b::RawPlane)::Float64
    n1 = plane_normal(a)
    n2 = plane_normal(b)
    dot = n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]
    norm1 = sqrt(n1[1]^2 + n1[2]^2 + n1[3]^2)
    norm2 = sqrt(n2[1]^2 + n2[2]^2 + n2[3]^2)
    cos_val = clamp(dot / (norm1 * norm2), -1.0, 1.0)
    rad2deg(acos(cos_val))
end

function mean_plane(a::RawPlane, b::RawPlane)::RawPlane
    RawPlane(
        gamma_0=(a.gamma_0 + b.gamma_0) / 2.0,
        gamma_v=(a.gamma_v + b.gamma_v) / 2.0,
        gamma_q=(a.gamma_q + b.gamma_q) / 2.0,
        gamma_s=(a.gamma_s + b.gamma_s) / 2.0
    )
end

function is_origin_plane(plane::RawPlane)::Bool
    abs(plane.gamma_0) <= ORIGIN_EPS && abs(plane.gamma_v) <= ORIGIN_EPS
end

function reduce_planes_angle(planes::Vector{RawPlane}, tolerance_deg::Float64)::Vector{RawPlane}
    isempty(planes) && return RawPlane[]

    out = RawPlane[]
    sizehint!(out, length(planes))

    for candidate in planes
        if isempty(out)
            push!(out, candidate)
        else
            tail = out[end]
            if !is_origin_plane(tail) && !is_origin_plane(candidate) &&
               angle_deg(tail, candidate) < tolerance_deg
                out[end] = mean_plane(tail, candidate)
            else
                push!(out, candidate)
            end
        end
    end

    out
end

function reduce_planes(
    planes::Vector{RawPlane}, config::PlaneReductionConfig,
    pf::ProductionFunction, bounds::FittingBounds
)::Vector{RawPlane}
    if config isa AngleReduction
        reduce_planes_angle(planes, config.tolerance_deg)
    elseif config isa DistanceReduction
        planes
    else
        planes
    end
end
