using Test
using LabDessem.FPHA

function make_storage_pf()
    rows = [
        VhaRow(0.0, 380.0, 0.0),
        VhaRow(10_000.0, 396.0, 0.0),
        VhaRow(20_000.0, 404.0, 0.0),
        VhaRow(30_000.0, 408.0, 0.0),
    ]
    forebay = ForebayTable(rows, "STORAGE")
    tailrace = PolynomialTailrace(coefficients=(0.0, 0.0008, -2e-8, 0.0, 0.0))
    ProductionFunction(
        forebay,
        tailrace,
        2.0,
        0.92,
        3_000.0,
        5_000.0,
        "STORAGE"
    )
end

function make_ror_pf()
    rows = [
        VhaRow(14_999.0, 400.0, 0.0),
        VhaRow(15_001.0, 400.0, 0.0),
    ]
    forebay = ForebayTable(rows, "ROR")
    tailrace = ConstantTailrace(level_m=380.0)
    ProductionFunction(
        forebay,
        tailrace,
        0.0,
        0.90,
        500.0,
        100.0,
        "ROR"
    )
end

function make_storage_bounds()
    FittingBounds(
        v_min=0.0,
        v_max=30_000.0,
        n_volume_points=6,
        n_flow_points=6,
        n_spillage_points=2,
        max_planes_per_hydro=10,
        single_volume=false
    )
end

function make_ror_bounds()
    FittingBounds(
        v_min=14_999.0,
        v_max=15_001.0,
        n_volume_points=2,
        n_flow_points=4,
        n_spillage_points=2,
        max_planes_per_hydro=10,
        single_volume=true
    )
end

@testset "Build Cloud" begin
    @testset "Correct grid size" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        cloud = build_cloud(pf, bounds)
        @test length(cloud) == 6 * 6
    end

    @testset "All points finite" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        cloud = build_cloud(pf, bounds)
        for (v, q, g) in cloud
            @test isfinite(v)
            @test isfinite(q)
            @test isfinite(g)
        end
    end

    @testset "Generation non-negative" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        cloud = build_cloud(pf, bounds)
        for (_, _, g) in cloud
            @test g >= 0.0
        end
    end

    @testset "Run-of-river cloud" begin
        pf = make_ror_pf()
        bounds = make_ror_bounds()
        cloud = build_cloud(pf, bounds)
        @test length(cloud) == 2 * 4
    end
end

@testset "Fit Hull Planes" begin
    @testset "Storage plant produces planes" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        @test length(planes) >= 1
    end

    @testset "Run-of-river gamma_v near zero" begin
        pf = make_ror_pf()
        bounds = make_ror_bounds()
        # The RoR case with constant height creates a degenerate (planar) point cloud.
        # fit_hull_planes will either throw NoHyperplanesError or produce planes
        # with gamma_v clamped near zero when single_volume=true.
        # This tests the clamping behavior.
        try
            planes = fit_hull_planes(pf, bounds)
            for p in planes
                @test abs(p.gamma_v) < 1e-4
            end
        catch e
            # Degenerate clouds are expected for flat VHA curves
            @test e isa NoHyperplanesError || e isa DegenerateCloudError
        end
    end

    @testset "All planes have gamma_q >= 0" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        for p in planes
            @test p.gamma_q >= -1e-10
        end
    end

    @testset "All planes have gamma_s == 0 (hull stage)" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        for p in planes
            @test p.gamma_s == 0.0
        end
    end

    @testset "Deterministic output" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes1 = fit_hull_planes(pf, bounds)
        planes2 = fit_hull_planes(pf, bounds)
        @test length(planes1) == length(planes2)
        for (p1, p2) in zip(planes1, planes2)
            @test p1.gamma_0 == p2.gamma_0
            @test p1.gamma_v == p2.gamma_v
            @test p1.gamma_q == p2.gamma_q
        end
    end
end

@testset "Envelope Functions" begin
    @testset "envelope_max" begin
        planes = [
            RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.1, gamma_s=0.0),
            RawPlane(gamma_0=50.0, gamma_v=0.002, gamma_q=0.2, gamma_s=0.0),
        ]
        @test envelope_max(planes, 0.0, 0.0) ≈ 100.0 atol=1e-10
        @test envelope_max(planes, 10_000.0, 1_000.0) > 100.0
    end

    @testset "envelope_min" begin
        planes = [
            RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.1, gamma_s=0.0),
            RawPlane(gamma_0=50.0, gamma_v=0.002, gamma_q=0.2, gamma_s=0.0),
        ]
        @test envelope_min(planes, 0.0, 0.0) ≈ 50.0 atol=1e-10
    end

    @testset "Empty planes" begin
        planes = RawPlane[]
        @test envelope_max(planes, 0.0, 0.0) == -Inf
        @test envelope_min(planes, 0.0, 0.0) == Inf
    end
end

@testset "Alpha Correction" begin
    @testset "compute_alpha_fpha returns positive value" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha = compute_alpha_fpha(planes, pf, bounds)
        @test alpha > 0.0
        @test alpha < 2.0
    end

    @testset "Empty planes returns 1.0" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        alpha = compute_alpha_fpha(RawPlane[], pf, bounds)
        @test alpha == 1.0
    end

    @testset "scale_plane_affine scales all coefficients" begin
        plane = RawPlane(gamma_0=100.0, gamma_v=0.01, gamma_q=0.5, gamma_s=-0.1)
        alpha = 0.85
        scaled = scale_plane_affine(plane, alpha)
        @test scaled.gamma_0 ≈ 85.0 atol=1e-10
        @test scaled.gamma_v ≈ 0.0085 atol=1e-12
        @test scaled.gamma_q ≈ 0.425 atol=1e-10
        @test scaled.gamma_s ≈ -0.085 atol=1e-10
    end

    @testset "scale_planes applies to all" begin
        planes = [
            RawPlane(gamma_0=100.0, gamma_v=0.01, gamma_q=0.5, gamma_s=0.0),
            RawPlane(gamma_0=200.0, gamma_v=0.02, gamma_q=0.6, gamma_s=0.0),
        ]
        scaled = scale_planes(planes, 0.9)
        @test length(scaled) == 2
        @test scaled[1].gamma_0 ≈ 90.0 atol=1e-10
        @test scaled[2].gamma_0 ≈ 180.0 atol=1e-10
    end

    @testset "Deterministic alpha" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha1 = compute_alpha_fpha(planes, pf, bounds)
        alpha2 = compute_alpha_fpha(planes, pf, bounds)
        @test alpha1 == alpha2
    end
end

@testset "Gamma_s Secant Fitting" begin
    @testset "resolve_s_max uses MLT when positive" begin
        @test resolve_s_max(1_500.0, 3_000.0) == 3_000.0
        @test resolve_s_max(0.0, 3_000.0) == 6_000.0
        @test resolve_s_max(-1.0, 2_000.0) == 4_000.0
    end

    @testset "gamma_s is non-positive" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha = compute_alpha_fpha(planes, pf, bounds)
        scaled = scale_planes(planes, alpha)
        fit_gamma_s_for_planes!(scaled, pf, bounds, 1_500.0)
        for p in scaled
            @test p.gamma_s <= 1e-10
        end
    end

    @testset "Flat tailrace yields zero slope" begin
        rows = [
            VhaRow(0.0, 400.0, 0.0),
            VhaRow(30_000.0, 420.0, 0.0),
        ]
        forebay = ForebayTable(rows, "FLAT")
        tailrace = ConstantTailrace(level_m=10.0)
        pf = ProductionFunction(
            forebay,
            tailrace,
            0.0,
            1.0,
            3_000.0,
            5_000.0,
            "FLAT"
        )
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha = compute_alpha_fpha(planes, pf, bounds)
        scaled = scale_planes(planes, alpha)
        fit_gamma_s_for_planes!(scaled, pf, bounds, 0.0)
        for p in scaled
            @test p.gamma_s == 0.0
        end
    end

    @testset "Deterministic gamma_s" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha = compute_alpha_fpha(planes, pf, bounds)
        scaled1 = scale_planes(planes, alpha)
        scaled2 = scale_planes(planes, alpha)
        fit_gamma_s_for_planes!(scaled1, pf, bounds, 1_500.0)
        fit_gamma_s_for_planes!(scaled2, pf, bounds, 1_500.0)
        for (p1, p2) in zip(scaled1, scaled2)
            @test p1.gamma_s == p2.gamma_s
        end
    end
end

@testset "Plane Reduction" begin
    @testset "is_origin_plane" begin
        @test is_origin_plane(RawPlane(gamma_0=0.0, gamma_v=0.0, gamma_q=1.0, gamma_s=0.0))
        @test !is_origin_plane(RawPlane(gamma_0=1.0, gamma_v=0.0, gamma_q=1.0, gamma_s=0.0))
        @test !is_origin_plane(RawPlane(gamma_0=0.0, gamma_v=0.001, gamma_q=1.0, gamma_s=0.0))
    end

    @testset "angle_deg between identical normals" begin
        a = RawPlane(gamma_0=100.0, gamma_v=0.002, gamma_q=0.85, gamma_s=0.0)
        b = RawPlane(gamma_0=200.0, gamma_v=0.002, gamma_q=0.85, gamma_s=0.0)
        @test angle_deg(a, b) < 1e-10
    end

    @testset "angle_deg between different normals" begin
        a = RawPlane(gamma_0=100.0, gamma_v=0.0, gamma_q=1.0, gamma_s=0.0)
        b = RawPlane(gamma_0=100.0, gamma_v=0.01, gamma_q=1.0, gamma_s=0.0)
        @test angle_deg(a, b) > 0.0
    end

    @testset "mean_plane averages all coefficients" begin
        a = RawPlane(gamma_0=100.0, gamma_v=0.002, gamma_q=0.8, gamma_s=-0.01)
        b = RawPlane(gamma_0=200.0, gamma_v=0.004, gamma_q=0.9, gamma_s=-0.03)
        m = mean_plane(a, b)
        @test m.gamma_0 ≈ 150.0 atol=1e-10
        @test m.gamma_v ≈ 0.003 atol=1e-12
        @test m.gamma_q ≈ 0.85 atol=1e-10
        @test m.gamma_s ≈ -0.02 atol=1e-10
    end

    @testset "reduce_planes_angle merges similar planes" begin
        a = RawPlane(gamma_0=100.0, gamma_v=0.002, gamma_q=0.85, gamma_s=-0.01)
        b = RawPlane(gamma_0=200.0, gamma_v=0.002, gamma_q=0.85, gamma_s=-0.03)
        reduced = reduce_planes_angle([a, b], 1.0)
        @test length(reduced) == 1
    end

    @testset "reduce_planes_angle preserves origin plane" begin
        origin = RawPlane(gamma_0=0.0, gamma_v=0.0, gamma_q=1.0, gamma_s=0.0)
        neighbour = RawPlane(gamma_0=0.0, gamma_v=0.0001, gamma_q=1.0, gamma_s=0.0)
        reduced = reduce_planes_angle([origin, neighbour], 90.0)
        @test length(reduced) == 2
    end

    @testset "zero tolerance merges nothing" begin
        a = RawPlane(gamma_0=100.0, gamma_v=0.002, gamma_q=0.85, gamma_s=-0.01)
        b = RawPlane(gamma_0=200.0, gamma_v=0.002, gamma_q=0.85, gamma_s=-0.03)
        reduced = reduce_planes_angle([a, b], 0.0)
        @test length(reduced) == 2
    end

    @testset "reduce_planes with AngleReduction config" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        config = AngleReduction(tolerance_deg=1.0)
        reduced = reduce_planes(planes, config, pf, bounds)
        @test length(reduced) <= length(planes)
    end
end

@testset "Deviation Computation" begin
    @testset "compute_fit_deviation with empty planes" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        dev = compute_fit_deviation(RawPlane[], pf, bounds)
        @test dev.mean_abs_mw == 0.0
        @test dev.relative == 0.0
    end

    @testset "compute_fit_deviation with fitted planes" begin
        pf = make_storage_pf()
        bounds = make_storage_bounds()
        planes = fit_hull_planes(pf, bounds)
        alpha = compute_alpha_fpha(planes, pf, bounds)
        scaled = scale_planes(planes, alpha)
        dev = compute_fit_deviation(scaled, pf, bounds)
        @test dev.mean_abs_mw >= 0.0
        @test dev.max_abs_mw >= dev.mean_abs_mw
        @test dev.rms_mw >= 0.0
        @test dev.relative >= 0.0
        @test dev.relative < 1.0
    end

    @testset "exceeds_warn_threshold" begin
        good = FphaFitDeviation(
            mean_abs_mw=10.0, max_abs_mw=20.0, rms_mw=15.0,
            mean_signed_mw=5.0, relative=0.02
        )
        @test !exceeds_warn_threshold(good)

        bad = FphaFitDeviation(
            mean_abs_mw=100.0, max_abs_mw=200.0, rms_mw=150.0,
            mean_signed_mw=50.0, relative=0.10
        )
        @test exceeds_warn_threshold(bad)
    end
end

@testset "Plane Validation" begin
    @testset "Valid planes pass" begin
        planes = [
            RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.5, gamma_s=-0.01),
            RawPlane(gamma_0=50.0, gamma_v=0.0, gamma_q=0.3, gamma_s=0.0),
        ]
        @test validate_fitted_planes(planes, 0.95, "ValidHydro") === nothing
    end

    @testset "Empty planes throws error" begin
        @test_throws NoHyperplanesError validate_fitted_planes(RawPlane[], 1.0, "Empty")
    end

    @testset "Zero alpha throws error" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.5, gamma_s=0.0)]
        @test_throws NonPositiveAlphaError validate_fitted_planes(planes, 0.0, "ZeroAlpha")
    end

    @testset "Negative alpha throws error" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.5, gamma_s=0.0)]
        @test_throws NonPositiveAlphaError validate_fitted_planes(planes, -0.5, "NegAlpha")
    end

    @testset "Negative gamma_v throws error" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=-0.001, gamma_q=0.5, gamma_s=0.0)]
        @test_throws InvalidCoefficientError validate_fitted_planes(planes, 1.0, "NegGammaV")
    end

    @testset "Negative gamma_q throws error" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=-0.001, gamma_s=0.0)]
        @test_throws InvalidCoefficientError validate_fitted_planes(planes, 1.0, "NegGammaQ")
    end

    @testset "Positive gamma_s throws error" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=0.001, gamma_q=0.5, gamma_s=0.001)]
        @test_throws InvalidCoefficientError validate_fitted_planes(planes, 1.0, "PosGammaS")
    end

    @testset "Within tolerance passes" begin
        planes = [RawPlane(gamma_0=100.0, gamma_v=-1e-11, gamma_q=-1e-11, gamma_s=1e-11)]
        @test validate_fitted_planes(planes, 1.0, "Tolerance") === nothing
    end
end
