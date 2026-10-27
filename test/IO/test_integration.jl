@testset "Integration" begin
    test_data_dir = normpath(joinpath(@__DIR__, "../../../labdessem_rust/examples/24Barras"))
    
    @testset "read_study_from_path_with_options" begin
        if !isdir(test_data_dir)
            @warn "24Barras test data not available, skipping integration tests"
        else
            # Use explicit options to skip FCF (stub not implemented) and fpha (precomputed)
            system = read_study_from_path_with_options(
                test_data_dir,
                false,  # ton_residual
                true,   # network
                true,   # uct
                false,  # uch
                false,  # fpha
                false   # fcf (skip - stub)
            )
            
            @test system.horizon.periods > 0
            @test length(system.submarkets) > 0
            @test length(system.buses) > 0
            @test length(system.branches) > 0
            @test length(system.thermal_plants) > 0
            @test length(system.hydro_plants) > 0
            
            @test system.thermal_unit_commitment_enabled == true
            @test system.hydro_unit_commitment_enabled == false
            @test system.ton_residual_enabled == false
            @test system.fpha_enabled == false
            @test system.future_cost_enabled == false
        end
    end
    
    @testset "read_study_from_path missing config" begin
        mktempdir() do tmpdir
            @test_throws ArgumentError read_study_from_path(tmpdir)
        end
    end
    
    @testset "read_study_from_path_with_options network disabled" begin
        if !isdir(test_data_dir)
            @warn "24Barras test data not available, skipping integration tests"
        else
            system = read_study_from_path_with_options(
                test_data_dir,
                false,  # ton_residual
                false,  # network
                false,  # uct
                false,  # uch
                false,  # fpha
                false   # fcf
            )
            
            @test !system.thermal_unit_commitment_enabled
            @test !system.hydro_unit_commitment_enabled
            @test !system.ton_residual_enabled
            @test !system.fpha_enabled
            @test !system.future_cost_enabled
            
            @test length(system.submarkets) > 0
            @test length(system.buses) > 0
            @test isempty(system.branches)
        end
    end
end
