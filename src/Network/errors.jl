abstract type NetworkError <: Exception end

struct NoReferenceBusError <: NetworkError end

function Base.showerror(io::IO, ::NoReferenceBusError)
    print(io, "NoReferenceBusError: no reference (slack) bus found in system")
end

struct SingularMatrixError <: NetworkError
    context::String
end

SingularMatrixError() = SingularMatrixError("matrix")

function Base.showerror(io::IO, e::SingularMatrixError)
    print(io, "SingularMatrixError: $(e.context) is singular")
end

struct DimensionMismatchError <: NetworkError
    expected::Int
    actual::Int
end

function Base.showerror(io::IO, e::DimensionMismatchError)
    print(io, "DimensionMismatchError: expected $(e.expected), got $(e.actual)")
end

struct NoBranchesError <: NetworkError end

function Base.showerror(io::IO, ::NoBranchesError)
    print(io, "NoBranchesError: system has no branches")
end
