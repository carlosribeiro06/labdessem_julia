module FPHA

include("types.jl")
include("errors.jl")
include("geometry.jl")
include("pipeline_types.jl")
include("grid.jl")
include("production.jl")
include("hull.jl")
include("fitting.jl")
include("calculator.jl")

export TailraceModel, ConstantTailrace, PolynomialTailrace
export FittingBounds
export RawPlane
export PlaneReductionConfig, AngleReduction, DistanceReduction
export FphaPlantConfig, FphaFitDeviation, FphaPlantResult
export WARN_RELATIVE_THRESHOLD
export VhaRow, ForebayTable
export GridParams
export Hyperplane3d, EPS_NZ, GAMMA_V_EPS
export ProductionFunction, K_GRAVITY
export evaluate, validate, interpolate, v_min, v_max, hydro_name
export tailrace_level, net_head, evaluate_capped
export build_grid, resolve_fitting_bounds
export exceeds_warn_threshold
export convex_hull_3d, extract_upper_envelope, convex_hull_upper_envelope
export build_cloud, fit_hull_planes, envelope_max, envelope_min
export compute_alpha_fpha, scale_plane_affine, scale_planes
export N_LATERAL_FLOW_SAMPLES, GAMMA_S_SNAP_EPS
export resolve_s_max, fit_gamma_s_for_planes!
export ORIGIN_EPS, is_origin_plane, angle_deg, mean_plane
export reduce_planes_angle, reduce_planes
export SIGN_TOLERANCE, compute_fit_deviation, validate_fitted_planes
export calculate_max_swallowing, FitPlantParams, fit_plant, fit_plants

export FPHAFittingError
export InsufficientPointsError, DuplicateVolumeError, DegenerateCloudError
export HullComputationError, NoHyperplanesError, NonPositiveAlphaError
export InvalidCoefficientError

end
