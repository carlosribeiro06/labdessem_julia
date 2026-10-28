using Test
using LabDessem.FPHA

@testset "FPHAFittingError Hierarchy" begin
    @testset "InsufficientPointsError" begin
        err = InsufficientPointsError("CAMARGOS", 1)
        @test err isa FPHAFittingError
        @test err isa Exception
        @test err.hydro_name == "CAMARGOS"
        @test err.count == 1
        msg = sprint(showerror, err)
        @test occursin("InsufficientPointsError", msg)
        @test occursin("CAMARGOS", msg)
        @test occursin("1", msg)
    end

    @testset "DuplicateVolumeError" begin
        err = DuplicateVolumeError("FURNAS", 1234.5)
        @test err isa FPHAFittingError
        @test err.hydro_name == "FURNAS"
        @test err.volume == 1234.5
        msg = sprint(showerror, err)
        @test occursin("DuplicateVolumeError", msg)
        @test occursin("FURNAS", msg)
    end

    @testset "DegenerateCloudError" begin
        err = DegenerateCloudError("ITAIPU", 100)
        @test err isa FPHAFittingError
        @test err.hydro_name == "ITAIPU"
        @test err.n_points == 100
        msg = sprint(showerror, err)
        @test occursin("degenerate", msg)
    end

    @testset "HullComputationError" begin
        err = HullComputationError("TUCURUI", "qhull precision error")
        @test err isa FPHAFittingError
        @test err.reason == "qhull precision error"
        msg = sprint(showerror, err)
        @test occursin("convex hull", msg)
    end

    @testset "NoHyperplanesError" begin
        err = NoHyperplanesError("SOBRADINHO")
        @test err isa FPHAFittingError
        msg = sprint(showerror, err)
        @test occursin("no valid hyperplanes", msg)
    end

    @testset "NonPositiveAlphaError" begin
        err = NonPositiveAlphaError("XINGO", -0.5)
        @test err isa FPHAFittingError
        @test err.alpha == -0.5
        msg = sprint(showerror, err)
        @test occursin("α", msg) || occursin("alpha", msg)
    end

    @testset "InvalidCoefficientError" begin
        err = InvalidCoefficientError("MARIMBONDO", :gamma_v, -0.1, "≥ 0")
        @test err isa FPHAFittingError
        @test err.coefficient == :gamma_v
        @test err.value == -0.1
        msg = sprint(showerror, err)
        @test occursin("gamma_v", msg)
    end

    @testset "Errors can be thrown and caught" begin
        @test_throws FPHAFittingError throw(InsufficientPointsError("TEST", 0))
        @test_throws InsufficientPointsError throw(InsufficientPointsError("TEST", 0))
        
        caught = false
        try
            throw(NoHyperplanesError("TEST"))
        catch e
            if e isa FPHAFittingError
                caught = true
            end
        end
        @test caught
    end
end
