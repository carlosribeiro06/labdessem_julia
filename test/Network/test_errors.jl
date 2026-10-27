using Test
using LabDessem.Network

@testset "Network Errors" begin
    @testset "NetworkError hierarchy" begin
        @test NoReferenceBusError <: NetworkError
        @test SingularMatrixError <: NetworkError
        @test DimensionMismatchError <: NetworkError
        @test NoBranchesError <: NetworkError
        @test NetworkError <: Exception
    end

    @testset "NoReferenceBusError" begin
        e = NoReferenceBusError()
        msg = sprint(showerror, e)
        @test occursin("no reference", msg)
        @test occursin("slack", msg)
    end

    @testset "SingularMatrixError" begin
        e = SingularMatrixError("susceptance matrix")
        msg = sprint(showerror, e)
        @test occursin("susceptance matrix", msg)
        @test occursin("singular", msg)

        e2 = SingularMatrixError()
        msg2 = sprint(showerror, e2)
        @test occursin("matrix", msg2)
    end

    @testset "DimensionMismatchError" begin
        e = DimensionMismatchError(10, 5)
        msg = sprint(showerror, e)
        @test occursin("10", msg)
        @test occursin("5", msg)
        @test occursin("expected", msg)
    end

    @testset "NoBranchesError" begin
        e = NoBranchesError()
        msg = sprint(showerror, e)
        @test occursin("no branches", msg)
    end

    @testset "throw and catch" begin
        @test_throws NoReferenceBusError throw(NoReferenceBusError())
        @test_throws SingularMatrixError throw(SingularMatrixError("test"))
        @test_throws DimensionMismatchError throw(DimensionMismatchError(1, 2))
        @test_throws NoBranchesError throw(NoBranchesError())
    end
end
