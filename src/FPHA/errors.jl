abstract type FPHAFittingError <: Exception end

struct InsufficientPointsError <: FPHAFittingError
    hydro_name::String
    count::Int
end

Base.showerror(io::IO, e::InsufficientPointsError) =
    print(io, "InsufficientPointsError: hydro '$(e.hydro_name)' has only $(e.count) VHA points (need ≥ 2)")

struct DuplicateVolumeError <: FPHAFittingError
    hydro_name::String
    volume::Float64
end

Base.showerror(io::IO, e::DuplicateVolumeError) =
    print(io, "DuplicateVolumeError: hydro '$(e.hydro_name)' has duplicate volume $(e.volume) hm³")

struct DegenerateCloudError <: FPHAFittingError
    hydro_name::String
    n_points::Int
end

Base.showerror(io::IO, e::DegenerateCloudError) =
    print(io, "DegenerateCloudError: hydro '$(e.hydro_name)' point cloud with $(e.n_points) points is degenerate")

struct HullComputationError <: FPHAFittingError
    hydro_name::String
    reason::String
end

Base.showerror(io::IO, e::HullComputationError) =
    print(io, "HullComputationError: hydro '$(e.hydro_name)' convex hull failed: $(e.reason)")

struct NoHyperplanesError <: FPHAFittingError
    hydro_name::String
end

Base.showerror(io::IO, e::NoHyperplanesError) =
    print(io, "NoHyperplanesError: hydro '$(e.hydro_name)' produced no valid hyperplanes")

struct NonPositiveAlphaError <: FPHAFittingError
    hydro_name::String
    alpha::Float64
end

Base.showerror(io::IO, e::NonPositiveAlphaError) =
    print(io, "NonPositiveAlphaError: hydro '$(e.hydro_name)' computed α = $(e.alpha) ≤ 0")

struct InvalidCoefficientError <: FPHAFittingError
    hydro_name::String
    coefficient::Symbol
    value::Float64
    constraint::String
end

Base.showerror(io::IO, e::InvalidCoefficientError) =
    print(io, "InvalidCoefficientError: hydro '$(e.hydro_name)' has $(e.coefficient) = $(e.value), expected $(e.constraint)")
