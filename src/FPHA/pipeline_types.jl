abstract type PlaneReductionConfig end

Base.@kwdef struct AngleReduction <: PlaneReductionConfig
    tolerance_deg::Float64 = 1.0
end

Base.@kwdef struct DistanceReduction <: PlaneReductionConfig
    tolerance_pct::Float64 = 0.5
    n_samples::Int = 64
end

Base.@kwdef struct FphaPlantConfig
    mode::Symbol = :precomputed
    max_planes::Int = 10
    volume_points::Int = 6
    flow_points::Int = 6
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

Base.@kwdef struct FphaPlantResult
    codigo::Int
    nome::String
    planes::Vector{RawPlane}
    alpha::Float64
    deviation::FphaFitDeviation
end
