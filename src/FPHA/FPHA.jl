module FPHA

include("types.jl")
include("errors.jl")
include("geometry.jl")
include("pipeline_types.jl")
include("grid.jl")
include("hull.jl")
include("fitting.jl")
include("production.jl")
include("calculator.jl")

export TailraceModel, ConstantTailrace, PolynomialTailrace
export FittingBounds
export RawPlane
export PlaneReductionConfig, AngleReduction, DistanceReduction
export FphaPlantConfig, FphaFitDeviation, FphaPlantResult
export WARN_RELATIVE_THRESHOLD
export VhaRow, ForebayTable
export GridParams
export ProductionFunction, K_GRAVITY
export evaluate, validate, interpolate, v_min, v_max, hydro_name
export tailrace_level, net_head, evaluate_capped
export build_grid, resolve_fitting_bounds
export exceeds_warn_threshold

export FPHAFittingError
export InsufficientPointsError, DuplicateVolumeError, DegenerateCloudError
export HullComputationError, NoHyperplanesError, NonPositiveAlphaError
export InvalidCoefficientError

end
