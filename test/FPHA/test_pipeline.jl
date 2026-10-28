using Test
using LabDessem.FPHA

function make_storage_params()
    rows = [
        VhaRow(0.0, 380.0, 1000.0),
        VhaRow(10_000.0, 396.0, 1200.0),
        VhaRow(20_000.0, 404.0, 1300.0),
        VhaRow(30_000.0, 408.0, 1400.0),
    ]
    forebay = ForebayTable(rows, "STORAGE")
    tailrace = PolynomialTailrace(coefficients=(0.0, 0.0008, -2e-8, 0.0, 0.0))
    FitPlantParams(
        codigo=1,
        nome="STORAGE",
        forebay=forebay,
        tailrace=tailrace,
        hydraulic_loss_m=2.0,
        efficiency=0.92,
        max_turbined_m3s=3_000.0,
        max_generation_mw=5_000.0,
        long_term_mean_inflow_m3s=1_500.0,
        config=FphaPlantConfig(
            mode=:computed,
            max_planes=10,
            volume_points=6,
            flow_points=6,
            reduction_config=AngleReduction(tolerance_deg=1.0)
        )
    )
end

function make_high_head_params()
    rows = [
        VhaRow(0.0, 600.0, 100.0),
        VhaRow(5_000.0, 700.0, 120.0),
        VhaRow(10_000.0, 750.0, 140.0),
    ]
    forebay = ForebayTable(rows, "HIGH_HEAD")
    tailrace = PolynomialTailrace(coefficients=(200.0, 0.001, 0.0, 0.0, 0.0))
    FitPlantParams(
        codigo=3,
        nome="HIGH_HEAD",
        forebay=forebay,
        tailrace=tailrace,
        hydraulic_loss_m=5.0,
        efficiency=0.88,
        max_turbined_m3s=1_000.0,
        max_generation_mw=4_000.0,
        long_term_mean_inflow_m3s=800.0,
        config=FphaPlantConfig(
            mode=:computed,
            max_planes=10,
            volume_points=4,
            flow_points=6,
            reduction_config=AngleReduction(tolerance_deg=1.0)
        )
    )
end

@testset "EngMax Calculator" begin
    @testset "Normal case Francis alpha" begin
        result = calculate_max_swallowing(100.0, 50.0, 40.0, 0.5)
        @test abs(result - 89.44) < 0.01
    end

    @testset "Net head exceeds effective head" begin
        result = calculate_max_swallowing(100.0, 50.0, 60.0, 0.5)
        @test abs(result - 109.54) < 0.01
    end

    @testset "Effective head zero fallback" begin
        result = calculate_max_swallowing(100.0, 0.0, 40.0, 0.5)
        @test result == 100.0
    end

    @testset "Net head zero fallback" begin
        result = calculate_max_swallowing(100.0, 50.0, 0.0, 0.5)
        @test result == 0.0
    end

    @testset "Kaplan alpha" begin
        result = calculate_max_swallowing(100.0, 50.0, 40.0, 0.2)
        @test abs(result - 95.64) < 0.01
    end
end

@testset "Pipeline Orchestration" begin
    @testset "fit_plant produces valid result" begin
        params = make_storage_params()
        result = fit_plant(params)
        @test result.codigo == 1
        @test result.nome == "STORAGE"
        @test !isempty(result.planes)
        @test result.alpha > 0.0
    end

    @testset "Planes pass validation" begin
        params = make_storage_params()
        result = fit_plant(params)
        for plane in result.planes
            @test plane.gamma_v >= -1e-10
            @test plane.gamma_q >= -1e-10
            @test plane.gamma_s <= 1e-10
        end
    end

    @testset "fit_plant is deterministic" begin
        params = make_storage_params()
        r1 = fit_plant(params)
        r2 = fit_plant(params)
        @test length(r1.planes) == length(r2.planes)
        @test r1.alpha == r2.alpha
        for (p1, p2) in zip(r1.planes, r2.planes)
            @test p1.gamma_0 == p2.gamma_0
            @test p1.gamma_v == p2.gamma_v
            @test p1.gamma_q == p2.gamma_q
            @test p1.gamma_s == p2.gamma_s
        end
    end

    @testset "High head plant fits successfully" begin
        params = make_high_head_params()
        result = fit_plant(params)
        @test !isempty(result.planes)
        @test result.deviation.relative < 0.15
    end
end

@testset "Batch Fitting" begin
    @testset "fit_plants handles multiple plants" begin
        params_list = [make_storage_params(), make_high_head_params()]
        results = fit_plants(params_list)
        @test length(results) == 2
        for r in results
            @test r isa FphaPlantResult
        end
    end
end
