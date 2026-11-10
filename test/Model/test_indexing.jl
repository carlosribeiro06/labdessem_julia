using Test
using LabDessem
using LabDessem.Model
import LabDessem.Domain

@testset "IndexSets" begin
    @testset "build_index_sets with thermal plants" begin
        plants = [
            make_thermal_plant_with_units(1, 3;
                pmin=10.0, startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
                time_in_state=10, startup_cost=0.0),
            make_thermal_plant_with_units(2, 2;
                pmin=10.0, startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
                time_in_state=10, startup_cost=0.0)
        ]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        
        sets = build_index_sets(system)
        
        @test length(sets.periods) == 4
        @test sets.periods == [1, 2, 3, 4]
        @test length(sets.thermal_indices) == 20  # 5 units × 4 periods
        
        plant1_indices = filter(idx -> idx[1] == 1, sets.thermal_indices)
        @test length(plant1_indices) == 12  # 3 units × 4 periods
    end
    
    @testset "build_index_sets with hydro plants" begin
        plants = [make_hydro_plant_with_groups(1, [(1, 1), (2, 1)];
            reservoir=Domain.Reservoir(min_volume_hm3=10.0, max_volume_hm3=100.0, initial_volume_hm3=50.0),
            spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.05, specific_productivity_mw_per_m3s=0.1,
            max_turbining_hm3=10.0, effective_head_m=50.0, time_in_state=10)]  # 2 groups, 1 unit each
        system = make_test_system(num_periods=4, hydro_plants=plants)
        
        sets = build_index_sets(system)
        
        @test length(sets.hydro_indices) == 8  # 2 groups × 1 unit × 4 periods
        @test length(sets.hydro_plant_periods) == 4  # 1 plant × 4 periods
    end
    
    @testset "build_index_sets with empty collections" begin
        system = make_test_system(num_periods=4)
        
        sets = build_index_sets(system)
        
        @test isempty(sets.thermal_indices)
        @test isempty(sets.hydro_indices)
        @test isempty(sets.hydro_plant_periods)
        @test isempty(sets.renewable_indices)
        @test isempty(sets.pumping_indices)
        @test isempty(sets.interchange_indices)
        @test isempty(sets.submarket_periods)
        @test sets.periods == [1, 2, 3, 4]
    end
    
    @testset "build_index_sets validates periods" begin
        system = make_test_system(num_periods=0)
        @test_throws ArgumentError build_index_sets(system)
    end
    
    @testset "build_index_sets with submarkets" begin
        submarkets = [
            Domain.Submarket(id=1, name="SE", demand_mw=fill(1000.0, 4)),
            Domain.Submarket(id=2, name="NE", demand_mw=fill(800.0, 4))
        ]
        system = make_test_system(num_periods=4, submarkets=submarkets)
        
        sets = build_index_sets(system)
        
        @test length(sets.submarket_periods) == 8  # 2 submarkets × 4 periods
    end
    
    @testset "build_index_sets with interchange limits" begin
        limits = [
            Domain.InterchangeLimit(from_submarket_id=1, to_submarket_id=2, max_flow_mw=500.0, penalty_cost_per_mwh=0.0),
            Domain.InterchangeLimit(from_submarket_id=2, to_submarket_id=1, max_flow_mw=400.0, penalty_cost_per_mwh=0.0)
        ]
        system = make_test_system(num_periods=4, interchange_limits=limits)
        
        sets = build_index_sets(system)
        
        @test length(sets.interchange_indices) == 8  # 2 directions × 4 periods
    end
    
    @testset "attach_index_sets!" begin
        container = ModelContainer()
        system = make_test_system(num_periods=4)
        sets = build_index_sets(system)
        
        @test container.index_sets === nothing
        attach_index_sets!(container, sets)
        @test container.index_sets === sets
    end
    
    @testset "thermal_gen_indices" begin
        plants = [
            make_thermal_plant_with_units(1, 3;
                pmin=10.0, startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
                time_in_state=10, startup_cost=0.0),
            make_thermal_plant_with_units(2, 2;
                pmin=10.0, startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
                time_in_state=10, startup_cost=0.0)
        ]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        sets = build_index_sets(system)
        
        indices = thermal_gen_indices(sets, 1)
        @test length(indices) == 12  # 3 units × 4 periods
        @test all(idx -> idx[1] == 1, indices)
        
        indices_missing = thermal_gen_indices(sets, 999)
        @test isempty(indices_missing)
    end
    
    @testset "hydro_gen_indices" begin
        plants = [make_hydro_plant_with_groups(1, [(1, 2), (2, 1)];
            reservoir=Domain.Reservoir(min_volume_hm3=10.0, max_volume_hm3=100.0, initial_volume_hm3=50.0),
            spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.05, specific_productivity_mw_per_m3s=0.1,
            max_turbining_hm3=10.0, effective_head_m=50.0, time_in_state=10)]  # 2 groups, 2+1 units
        system = make_test_system(num_periods=4, hydro_plants=plants)
        sets = build_index_sets(system)
        
        indices = hydro_gen_indices(sets, 1)
        @test length(indices) == 12  # 3 units × 4 periods
        @test all(idx -> idx[1] == 1, indices)
    end
    
    @testset "period_thermal_indices" begin
        plants = [make_thermal_plant_with_units(1, 2;
            pmin=10.0, startup_trajectory_mw=Float64[], shutdown_trajectory_mw=Float64[],
            time_in_state=10, startup_cost=0.0)]
        system = make_test_system(num_periods=4, thermal_plants=plants)
        sets = build_index_sets(system)
        
        indices = period_thermal_indices(sets, 2)
        @test length(indices) == 2  # 2 units in period 2
        @test all(idx -> idx[3] == 2, indices)
    end
    
    @testset "constraint_name" begin
        @test constraint_name("hydro_balance", (1, 5)) == "hydro_balance[1,5]"
        @test constraint_name("thermal_gen", (3, 2, 4)) == "thermal_gen[3,2,4]"
    end
end
