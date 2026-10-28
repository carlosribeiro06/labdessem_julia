using Test
using LabDessem.FPHA

@testset "GridParams and Grid Generation" begin
    @testset "build_grid produces correct number of points" begin
        bounds = FittingBounds(
            v_min=0.0, v_max=100.0,
            n_volume_points=5, n_flow_points=10, n_spillage_points=3
        )
        grid = build_grid(bounds, 500.0)
        @test length(grid.v_points) == 5
        @test length(grid.q_points) == 10
        @test length(grid.s_points) == 3
    end

    @testset "Grid values are uniformly spaced" begin
        bounds = FittingBounds(
            v_min=0.0, v_max=100.0,
            n_volume_points=5, n_flow_points=5, n_spillage_points=5
        )
        grid = build_grid(bounds, 400.0)

        v_step = 25.0
        for i in 2:length(grid.v_points)
            @test grid.v_points[i] - grid.v_points[i-1] ≈ v_step atol=1e-10
        end

        q_step = 100.0
        for i in 2:length(grid.q_points)
            @test grid.q_points[i] - grid.q_points[i-1] ≈ q_step atol=1e-10
        end
    end

    @testset "Grid includes endpoints" begin
        bounds = FittingBounds(
            v_min=10.0, v_max=90.0,
            n_volume_points=5, n_flow_points=5, n_spillage_points=5
        )
        grid = build_grid(bounds, 400.0)
        @test grid.v_points[1] == 10.0
        @test grid.v_points[end] == 90.0
        @test grid.q_points[1] == 0.0
        @test grid.q_points[end] == 400.0
        @test grid.s_points[1] == 0.0
        @test grid.s_points[end] == 400.0
    end

    @testset "single_volume flag produces 2-point volume range" begin
        bounds = FittingBounds(
            v_min=45.0, v_max=55.0,
            n_volume_points=10, n_flow_points=5, n_spillage_points=2,
            single_volume=true
        )
        grid = build_grid(bounds, 300.0)
        @test length(grid.v_points) == 2
        @test length(grid.q_points) == 5
    end

    @testset "Type stability" begin
        bounds = FittingBounds(v_min=0.0, v_max=100.0)
        @test @inferred(build_grid(bounds, 500.0)) isa GridParams
    end
end

@testset "resolve_fitting_bounds" begin
    @testset "Normal multi-volume plant" begin
        config = FittingBounds(
            v_min=0.0, v_max=0.0,
            n_volume_points=10, n_flow_points=10, n_spillage_points=2
        )
        resolved = resolve_fitting_bounds(10.0, 100.0, 90.0, config)
        @test resolved.v_min == 10.0
        @test resolved.v_max == 100.0
        @test resolved.n_volume_points == 10
        @test resolved.single_volume == false
    end

    @testset "Detects single-volume (zero span)" begin
        config = FittingBounds(
            v_min=0.0, v_max=0.0,
            n_volume_points=10, n_flow_points=10, n_spillage_points=2
        )
        resolved = resolve_fitting_bounds(50.0, 50.0, 100.0, config)
        @test resolved.single_volume == true
        @test resolved.n_volume_points == 2
        @test resolved.v_min < 50.0
        @test resolved.v_max > 50.0
    end

    @testset "Detects single-volume (n_volume_points=1)" begin
        config = FittingBounds(
            v_min=0.0, v_max=0.0,
            n_volume_points=1, n_flow_points=10, n_spillage_points=2
        )
        resolved = resolve_fitting_bounds(10.0, 100.0, 90.0, config)
        @test resolved.single_volume == true
        @test resolved.n_volume_points == 2
    end

    @testset "Synthesized range uses useful_storage" begin
        config = FittingBounds(
            v_min=0.0, v_max=0.0,
            n_volume_points=10, n_flow_points=10, n_spillage_points=2
        )
        useful_storage = 1000.0
        resolved = resolve_fitting_bounds(50.0, 50.0, useful_storage, config)

        expected_half_width = max(0.005 * useful_storage, 1.0)
        @test resolved.v_min ≈ 50.0 - expected_half_width atol=1e-10
        @test resolved.v_max ≈ 50.0 + expected_half_width atol=1e-10
    end

    @testset "Minimum half_width is 1.0 hm³" begin
        config = FittingBounds(
            v_min=0.0, v_max=0.0,
            n_volume_points=10, n_flow_points=10, n_spillage_points=2
        )
        useful_storage = 10.0
        resolved = resolve_fitting_bounds(5.0, 5.0, useful_storage, config)

        @test resolved.v_min == 5.0 - 1.0
        @test resolved.v_max == 5.0 + 1.0
    end
end
