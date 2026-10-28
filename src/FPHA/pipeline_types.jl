abstract type PlaneReductionConfig end

Base.@kwdef struct AngleReduction <: PlaneReductionConfig
    tolerance_deg::Float64 = 1.0
end

Base.@kwdef struct DistanceReduction <: PlaneReductionConfig
    tolerance_pct::Float64 = 0.5
    n_samples::Int = 64
end

Base.@kwdef struct FphaPlantConfig
    codigo::Int
    nome::String
    forebay::ForebayTable
    tailrace::Union{TailraceModel,Nothing} = nothing
    hydraulic_loss_m::Union{Float64,Nothing} = nothing
    efficiency::Union{Float64,Nothing} = nothing
    max_turbined_m3s::Float64
    max_generation_mw::Float64
    long_term_mean_inflow_m3s::Float64
    config_bounds::FittingBounds = FittingBounds(v_min=0.0, v_max=1.0)
    reduction_config::PlaneReductionConfig = AngleReduction()
end

const WARN_RELATIVE_THRESHOLD = 0.05

Base.@kwdef struct FphaFitDeviation
    mean_abs_mw::Float64 = 0.0
    max_abs_mw::Float64 = 0.0
    rms_mw::Float64 = 0.0
    mean_signed_mw::Float64 = 0.0
    relative::Float64 = 0.0
end

exceeds_warn_threshold(dev::FphaFitDeviation)::Bool = dev.relative > WARN_RELATIVE_THRESHOLD

struct FphaPlantResult
    codigo::Int
    nome::String
    planes::Vector{RawPlane}
    alpha::Float64
    deviation::FphaFitDeviation

    function FphaPlantResult(codigo::Int, nome::String, planes::Vector{RawPlane},
                             alpha::Float64, deviation::FphaFitDeviation)
        isempty(planes) && throw(NoHyperplanesError(nome))
        new(codigo, nome, planes, alpha, deviation)
    end
end
