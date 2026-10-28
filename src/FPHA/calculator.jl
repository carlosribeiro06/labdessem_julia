function calculate_max_swallowing(
    max_turbining_m3s::Float64, effective_head_m::Float64,
    net_head_m::Float64, alpha::Float64
)::Float64
    effective_head_m <= 0.0 && return max_turbining_m3s
    net_head_m <= 0.0 && return 0.0
    max_turbining_m3s * (net_head_m / effective_head_m)^alpha
end

Base.@kwdef struct FitPlantParams
    codigo::Int
    nome::String
    forebay::ForebayTable
    tailrace::Union{TailraceModel,Nothing} = nothing
    hydraulic_loss_m::Float64 = 0.0
    efficiency::Float64 = 1.0
    max_turbined_m3s::Float64
    max_generation_mw::Float64
    long_term_mean_inflow_m3s::Float64
    config::FphaPlantConfig
end

function fit_plant(params::FitPlantParams)::FphaPlantResult
    pf = ProductionFunction(
        forebay=params.forebay,
        tailrace=params.tailrace,
        hydraulic_loss_m=params.hydraulic_loss_m,
        efficiency=params.efficiency,
        max_turbined_m3s=params.max_turbined_m3s,
        max_generation_mw=params.max_generation_mw,
        hydro_name=params.nome
    )

    config_bounds = FittingBounds(
        v_min=v_min(params.forebay),
        v_max=v_max(params.forebay),
        n_volume_points=params.config.volume_points,
        n_flow_points=params.config.flow_points,
        n_spillage_points=2,
        max_planes_per_hydro=params.config.max_planes,
        single_volume=false
    )

    useful_storage_hm3 = v_max(params.forebay) - v_min(params.forebay)

    bounds = resolve_fitting_bounds(
        v_min(params.forebay), v_max(params.forebay),
        useful_storage_hm3, config_bounds
    )

    raw_planes = fit_hull_planes(pf, bounds)
    isempty(raw_planes) && throw(NoHyperplanesError(params.nome))

    alpha = compute_alpha_fpha(raw_planes, pf, bounds)
    scaled = scale_planes(raw_planes, alpha)

    fit_gamma_s_for_planes!(scaled, pf, bounds, params.long_term_mean_inflow_m3s)

    reduced = reduce_planes(scaled, params.config.reduction_config, pf, bounds)

    deviation = compute_fit_deviation(reduced, pf, bounds)

    validate_fitted_planes(reduced, alpha, params.nome)

    FphaPlantResult(
        codigo=params.codigo,
        nome=params.nome,
        planes=reduced,
        alpha=alpha,
        deviation=deviation
    )
end

function fit_plants(params_list::Vector{FitPlantParams})::Vector{Union{FphaPlantResult,Exception}}
    results = Union{FphaPlantResult,Exception}[]
    for params in params_list
        try
            push!(results, fit_plant(params))
        catch e
            push!(results, e)
        end
    end
    results
end
