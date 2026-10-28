using Test
using LabDessem.FPHA

@testset "ProductionFunction" begin
    function make_forebay(height::Float64)
        rows = [VhaRow(volume_hm3=0.0, height_m=height, area_km2=10.0)]
        ForebayTable(rows, "TEST")
    end

    function make_forebay_range(h_min::Float64, h_max::Float64)
        rows = [
            VhaRow(volume_hm3=0.0, height_m=h_min, area_km2=10.0),
            VhaRow(volume_hm3=100.0, height_m=h_max, area_km2=20.0),
        ]
        ForebayTable(rows, "TEST")
    end

    @testset "Construction" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            hydraulic_loss_m=0.0,
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        @test pf.efficiency == 0.9
        @test pf.max_turbined_m3s == 500.0
    end

    @testset "Zero flow returns zero" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        @test evaluate(pf, 50.0, 0.0, 0.0) == 0.0
        @test evaluate(pf, 50.0, 0.0, 100.0) == 0.0
    end

    @testset "Typical values match hand calculation" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            hydraulic_loss_m=0.0,
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        q = 100.0
        h_net = 400.0 - 350.0 - 0.0
        expected = K_GRAVITY * 0.9 * q * h_net
        @test expected ≈ 44.145 atol=1e-6
        @test evaluate(pf, 50.0, q, 0.0) ≈ expected atol=1e-10
    end

    @testset "Negative head returns zero" begin
        forebay = make_forebay(300.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        @test net_head(pf, 50.0, 100.0) == 0.0
        @test evaluate(pf, 50.0, 100.0, 0.0) == 0.0
    end

    @testset "With head loss" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            hydraulic_loss_m=5.0,
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        q = 100.0
        h_net = 400.0 - 350.0 - 5.0
        expected = K_GRAVITY * 0.9 * q * h_net
        @test evaluate(pf, 50.0, q, 0.0) ≈ expected atol=1e-10
    end

    @testset "evaluate_capped respects limit" begin
        forebay = make_forebay(500.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            efficiency=0.95,
            max_turbined_m3s=2000.0,
            max_generation_mw=100.0,
            hydro_name="TEST"
        )
        uncapped = evaluate(pf, 50.0, 1500.0, 0.0)
        @test uncapped > 100.0
        capped = evaluate_capped(pf, 50.0, 1500.0, 0.0)
        @test capped == 100.0
    end

    @testset "Without tailrace" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=nothing,
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        @test tailrace_level(pf, 100.0) == 0.0
        q = 100.0
        h_net = 400.0 - 0.0 - 0.0
        expected = K_GRAVITY * 0.9 * q * h_net
        @test evaluate(pf, 50.0, q, 0.0) ≈ expected atol=1e-10
    end

    @testset "Type stability" begin
        forebay = make_forebay(400.0)
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=ConstantTailrace(level_m=350.0),
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        @test @inferred(net_head(pf, 50.0, 100.0)) isa Float64
        @test @inferred(evaluate(pf, 50.0, 100.0, 0.0)) isa Float64
        @test @inferred(evaluate_capped(pf, 50.0, 100.0, 0.0)) isa Float64
    end

    @testset "Spillage affects tailrace" begin
        forebay = make_forebay(400.0)
        tailrace = PolynomialTailrace(coefficients=(350.0, 0.01, 0.0, 0.0, 0.0))
        pf = ProductionFunction(
            forebay=forebay,
            tailrace=tailrace,
            efficiency=0.9,
            max_turbined_m3s=500.0,
            max_generation_mw=200.0,
            hydro_name="TEST"
        )
        g_no_spill = evaluate(pf, 50.0, 100.0, 0.0)
        g_with_spill = evaluate(pf, 50.0, 100.0, 200.0)
        @test g_with_spill < g_no_spill
    end
end
