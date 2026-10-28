struct GridParams
    v_points::Vector{Float64}
    q_points::Vector{Float64}
    s_points::Vector{Float64}
end

const V_EPS = 1e-9
const V_SYNTH_ABS = 1.0
const V_SYNTH_FRAC = 0.005

function build_grid(bounds::FittingBounds, max_turbined_m3s::Float64)::GridParams
    v_points = if bounds.single_volume
        collect(range(bounds.v_min, bounds.v_max, length=2))
    else
        collect(range(bounds.v_min, bounds.v_max, length=bounds.n_volume_points))
    end

    q_points = collect(range(0.0, max_turbined_m3s, length=bounds.n_flow_points))
    s_points = collect(range(0.0, max_turbined_m3s, length=bounds.n_spillage_points))

    GridParams(v_points, q_points, s_points)
end

function resolve_fitting_bounds(
    forebay_v_min::Float64, forebay_v_max::Float64,
    useful_storage_hm3::Float64, config::FittingBounds
)::FittingBounds
    forebay_span = forebay_v_max - forebay_v_min
    single_volume = forebay_span <= V_EPS || config.n_volume_points == 1

    if single_volume
        v0 = forebay_v_min
        half_width = max(V_SYNTH_FRAC * useful_storage_hm3, V_SYNTH_ABS)
        return FittingBounds(
            v_min=v0 - half_width,
            v_max=v0 + half_width,
            n_volume_points=2,
            n_flow_points=config.n_flow_points,
            n_spillage_points=config.n_spillage_points,
            max_planes_per_hydro=config.max_planes_per_hydro,
            single_volume=true
        )
    end

    FittingBounds(
        v_min=forebay_v_min,
        v_max=forebay_v_max,
        n_volume_points=config.n_volume_points,
        n_flow_points=config.n_flow_points,
        n_spillage_points=config.n_spillage_points,
        max_planes_per_hydro=config.max_planes_per_hydro,
        single_volume=false
    )
end
