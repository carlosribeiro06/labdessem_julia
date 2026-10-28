using Test
using LabDessem.FPHA

@testset "TailraceModel" begin
    @testset "ConstantTailrace" begin
        model = ConstantTailrace(level_m=100.0)
        @test evaluate(model, 0.0) == 100.0
        @test evaluate(model, 500.0) == 100.0
        @test evaluate(model, 1000.0) == 100.0
        @test @inferred(evaluate(model, 100.0)) isa Float64
    end

    @testset "PolynomialTailrace" begin
        model = PolynomialTailrace(coefficients=(90.0, 0.01, 0.0, 0.0, 0.0))
        @test evaluate(model, 0.0) == 90.0
        @test evaluate(model, 500.0) == 95.0
        @test @inferred(evaluate(model, 100.0)) isa Float64

        model2 = PolynomialTailrace(coefficients=(100.0, 0.001, 0.00001, 0.0, 0.0))
        @test evaluate(model2, 0.0) == 100.0
        q = 100.0
        expected = 100.0 + 0.001 * q + 0.00001 * q^2
        @test evaluate(model2, q) ≈ expected atol=1e-10
    end

    @testset "Type stability" begin
        const_model = ConstantTailrace(level_m=50.0)
        poly_model = PolynomialTailrace(coefficients=(80.0, 0.02, 0.0001, 0.0, 0.0))
        @test @inferred(evaluate(const_model, 250.0)) isa Float64
        @test @inferred(evaluate(poly_model, 250.0)) isa Float64
    end
end

@testset "FittingBounds" begin
    @testset "Construction with all parameters" begin
        bounds = FittingBounds(
            v_min=100.0, v_max=500.0,
            n_volume_points=15, n_flow_points=20,
            n_spillage_points=3, max_planes_per_hydro=10,
            single_volume=false
        )
        @test bounds.v_min == 100.0
        @test bounds.v_max == 500.0
        @test bounds.n_volume_points == 15
        @test bounds.n_flow_points == 20
        @test bounds.n_spillage_points == 3
        @test bounds.max_planes_per_hydro == 10
        @test bounds.single_volume == false
    end

    @testset "Default values" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0)
        @test bounds.n_volume_points == 10
        @test bounds.n_flow_points == 10
        @test bounds.n_spillage_points == 2
        @test bounds.max_planes_per_hydro == 15
        @test bounds.single_volume == false
    end

    @testset "Validation - valid bounds" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0)
        @test validate(bounds) == true
    end

    @testset "Validation - v_min >= v_max" begin
        bounds = FittingBounds(v_min=100.0, v_max=100.0)
        @test validate(bounds) == false
        bounds2 = FittingBounds(v_min=200.0, v_max=100.0)
        @test validate(bounds2) == false
    end

    @testset "Validation - n_volume_points < 2" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0, n_volume_points=1)
        @test validate(bounds) == false
    end

    @testset "Validation - n_flow_points < 2" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0, n_flow_points=1)
        @test validate(bounds) == false
    end

    @testset "Validation - n_spillage_points < 1" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0, n_spillage_points=0)
        @test validate(bounds) == false
    end

    @testset "Validation - max_planes_per_hydro < 1" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0, max_planes_per_hydro=0)
        @test validate(bounds) == false
    end

    @testset "Type stability" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0)
        @test @inferred(FittingBounds(v_min=0.0, v_max=100.0)) isa FittingBounds
        @test @inferred(validate(bounds)) isa Bool
    end
end

@testset "RawPlane" begin
    @testset "Construction" begin
        plane = RawPlane(gamma_0=100.0, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        @test plane.gamma_0 == 100.0
        @test plane.gamma_v == 0.5
        @test plane.gamma_q == 0.1
        @test plane.gamma_s == -0.05
    end

    @testset "Evaluate" begin
        plane = RawPlane(gamma_0=100.0, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        result = evaluate(plane, 50.0, 200.0, 10.0)
        expected = 100.0 + 0.5 * 50.0 + 0.1 * 200.0 - 0.05 * 10.0
        @test result ≈ expected atol=1e-10
        @test result ≈ 144.5 atol=1e-10
    end

    @testset "isapprox" begin
        p1 = RawPlane(gamma_0=100.0, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        p2 = RawPlane(gamma_0=100.0 + 1e-10, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        p3 = RawPlane(gamma_0=100.1, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        @test isapprox(p1, p2, atol=1e-8)
        @test !isapprox(p1, p3, atol=1e-8)
    end

    @testset "Type stability" begin
        plane = RawPlane(gamma_0=100.0, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)
        @test @inferred(evaluate(plane, 50.0, 200.0, 10.0)) isa Float64
    end
end
