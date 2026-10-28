module FPHA

include("types.jl")
include("errors.jl")
include("geometry.jl")
include("hull.jl")
include("fitting.jl")
include("production.jl")
include("calculator.jl")

export TailraceModel, ConstantTailrace, PolynomialTailrace
export FittingBounds
export RawPlane
export VhaRow, ForebayTable
export evaluate, validate, interpolate, v_min, v_max, hydro_name

export FPHAFittingError
export InsufficientPointsError, DuplicateVolumeError, DegenerateCloudError
export HullComputationError, NoHyperplanesError, NonPositiveAlphaError
export InvalidCoefficientError

end
