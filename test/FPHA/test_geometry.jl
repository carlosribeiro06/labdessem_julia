using Test
using LabDessem.FPHA

@testset "VhaRow" begin
    @testset "Construction" begin
        row = VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=10.0)
        @test row.volume_hm3 == 50.0
        @test row.height_m == 400.0
        @test row.area_km2 == 10.0
    end
end

@testset "ForebayTable" begin
    @testset "Sorts rows by volume" begin
        rows = [
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=20.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test table.rows[1].volume_hm3 == 0.0
        @test table.rows[2].volume_hm3 == 50.0
        @test table.rows[3].volume_hm3 == 100.0
    end

    @testset "Accessors" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "CAMARGOS")
        @test v_min(table) == 0.0
        @test v_max(table) == 100.0
        @test hydro_name(table) == "CAMARGOS"
    end

    @testset "Interpolate at exact row volumes" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=20.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test interpolate(table, 0.0) ≈ 380.0 atol=1e-10
        @test interpolate(table, 50.0) ≈ 400.0 atol=1e-10
        @test interpolate(table, 100.0) ≈ 420.0 atol=1e-10
    end

    @testset "Interpolate between rows" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=20.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test interpolate(table, 25.0) ≈ 390.0 atol=1e-10
        @test interpolate(table, 75.0) ≈ 410.0 atol=1e-10
    end

    @testset "Clamps below minimum" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test interpolate(table, -10.0) ≈ 380.0 atol=1e-10
        @test interpolate(table, -100.0) ≈ 380.0 atol=1e-10
    end

    @testset "Clamps above maximum" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test interpolate(table, 150.0) ≈ 420.0 atol=1e-10
        @test interpolate(table, 1000.0) ≈ 420.0 atol=1e-10
    end

    @testset "Single-row table returns constant" begin
        rows = [VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=20.0)]
        table = ForebayTable(rows, "FIODAGUA")
        @test interpolate(table, 0.0) ≈ 400.0 atol=1e-10
        @test interpolate(table, 50.0) ≈ 400.0 atol=1e-10
        @test interpolate(table, 100.0) ≈ 400.0 atol=1e-10
    end

    @testset "Constructor rejects empty vector" begin
        @test_throws InsufficientPointsError ForebayTable(VhaRow[], "EMPTY")
    end

    @testset "Constructor rejects duplicate volumes" begin
        rows = [
            VhaRow(volume_hm3=50.0, height_m=400.0, area_km2=20.0),
            VhaRow(volume_hm3=50.0, height_m=410.0, area_km2=25.0),
        ]
        @test_throws DuplicateVolumeError ForebayTable(rows, "DUPLICADO")
    end

    @testset "Type stability" begin
        rows = [
            VhaRow(volume_hm3=0.0, height_m=380.0, area_km2=10.0),
            VhaRow(volume_hm3=100.0, height_m=420.0, area_km2=30.0),
        ]
        table = ForebayTable(rows, "TEST")
        @test @inferred(interpolate(table, 50.0)) isa Float64
        @test @inferred(v_min(table)) isa Float64
        @test @inferred(v_max(table)) isa Float64
        @test @inferred(hydro_name(table)) isa String
    end
end
