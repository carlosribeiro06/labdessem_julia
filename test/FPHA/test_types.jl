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

@testset "PlaneReductionConfig" begin
    @testset "AngleReduction" begin
        ar = AngleReduction()
        @test ar.tolerance_deg == 1.0
        ar2 = AngleReduction(tolerance_deg=2.5)
        @test ar2.tolerance_deg == 2.5
    end

    @testset "DistanceReduction" begin
        dr = DistanceReduction()
        @test dr.tolerance_pct == 0.5
        @test dr.n_samples == 64
        dr2 = DistanceReduction(tolerance_pct=1.0, n_samples=100)
        @test dr2.tolerance_pct == 1.0
        @test dr2.n_samples == 100
    end

    @testset "Subtype relationship" begin
        @test AngleReduction() isa PlaneReductionConfig
        @test DistanceReduction() isa PlaneReductionConfig
    end
end

@testset "FphaPlantConfig" begin
    @testset "Construction with defaults" begin
        config = FphaPlantConfig()
        @test config.mode == :precomputed
        @test config.max_planes == 10
        @test config.volume_points == 6
        @test config.flow_points == 6
        @test config.reduction_config isa AngleReduction
    end

    @testset "Construction with computed mode" begin
        config = FphaPlantConfig(
            mode=:computed,
            max_planes=15,
            volume_points=8,
            flow_points=8,
            reduction_config=DistanceReduction(tolerance_pct=1.0, n_samples=32)
        )
        @test config.mode == :computed
        @test config.max_planes == 15
        @test config.volume_points == 8
        @test config.reduction_config isa DistanceReduction
    end
end

@testset "FphaFitDeviation" begin
    @testset "Construction with defaults" begin
        dev = FphaFitDeviation()
        @test dev.mean_abs_mw == 0.0
        @test dev.max_abs_mw == 0.0
        @test dev.rms_mw == 0.0
        @test dev.mean_signed_mw == 0.0
        @test dev.relative == 0.0
    end

    @testset "Construction with values" begin
        dev = FphaFitDeviation(
            mean_abs_mw=1.5,
            max_abs_mw=3.0,
            rms_mw=2.0,
            mean_signed_mw=-0.5,
            relative=0.03
        )
        @test dev.mean_abs_mw == 1.5
        @test dev.max_abs_mw == 3.0
        @test dev.relative == 0.03
    end

    @testset "exceeds_warn_threshold" begin
        dev_ok = FphaFitDeviation(relative=0.04)
        @test exceeds_warn_threshold(dev_ok) == false

        dev_warn = FphaFitDeviation(relative=0.06)
        @test exceeds_warn_threshold(dev_warn) == true

        dev_boundary = FphaFitDeviation(relative=0.05)
        @test exceeds_warn_threshold(dev_boundary) == false
    end
end

@testset "FphaPlantResult" begin
    @testset "Construction with valid planes" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=0.5, gamma_q=0.1, gamma_s=-0.05)]
        dev = FphaFitDeviation()
        result = FphaPlantResult(codigo=1, nome="TESTE", planes=planes, alpha=1.02, deviation=dev)
        @test result.codigo == 1
        @test result.nome == "TESTE"
        @test length(result.planes) == 1
        @test result.alpha == 1.02
    end

    @testset "Rejects empty planes" begin
        planes = RawPlane[]
        dev = FphaFitDeviation()
        result = FphaPlantResult(codigo=1, nome="TESTE", planes=planes, alpha=1.0, deviation=dev)
        @test isempty(result.planes)
    end
end
