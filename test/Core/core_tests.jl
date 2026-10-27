using Test

include("../../src/Core/Core.jl")
using .Core

# Helper functions for creating valid entities

function make_thermal_initial_condition()
    ThermalInitialCondition(
        is_on=true, generation_mw=50.0, time_in_state=1,
        time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
    )
end

function make_thermal_unit(id=1; name="TU$(id)")
    ThermalUnit(
        id=id, name=name, min_generation_mw=0.0, max_generation_mw=100.0,
        startup_trajectory_mw=[50.0], shutdown_trajectory_mw=[50.0],
        min_up_time=1, min_down_time=1, startup_cost=1000.0, shutdown_cost=0.0,
        variable_cost_per_mwh=50.0, initial_condition=make_thermal_initial_condition()
    )
end

function make_thermal_plant(id=1; name="TP$(id)")
    ThermalPlant(id=id, name=name, submarket_id=1, bus_id=1, units=[make_thermal_unit(id)])
end

function make_reservoir()
    Reservoir(min_volume_hm3=0.0, max_volume_hm3=100.0, initial_volume_hm3=50.0)
end

function make_hydro_initial_condition()
    HydroInitialCondition(is_on=true, generation_mw=50.0, time_in_state=1)
end

function make_hydro_unit(id=1; name="HU$(id)")
    HydroUnit(
        id=id, name=name, min_generation_mw=0.0, max_generation_mw=100.0,
        max_turbining_hm3=50.0, effective_head_m=100.0,
        initial_condition=make_hydro_initial_condition()
    )
end

function make_hydro_group(id=1; name="HG$(id)")
    HydroGroup(id=id, name=name, units=[make_hydro_unit(id)])
end

function make_hydro_plant(id=1; name="HP$(id)", downstream_plant_id=nothing, upstream_plant_ids=Int[])
    HydroPlant(
        id=id, name=name, submarket_id=1, bus_id=1,
        upstream_plant_ids=upstream_plant_ids, downstream_plant_id=downstream_plant_id,
        diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
        reservoir=make_reservoir(),
        natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
        spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0,
        specific_productivity_mw_per_m3s=0.01, hydraulic_loss_m=nothing, efficiency=nothing,
        fpha_segments=HydroFphaSegment[], groups=[make_hydro_group(id)],
        turbine_type=Francis, volume_level_table=nothing, tailrace_coefficients=nothing
    )
end

function make_submarket(id=1; name="SM$(id)")
    Submarket(id=id, name=name, demand_mw=[100.0])
end

function make_bus(id=1; name="B$(id)", angle_reference=true)
    Bus(id=id, name=name, submarket_id=1, demand_mw=[50.0], angle_reference=angle_reference)
end

function make_branch(id=1; name="BR$(id)")
    Branch(id=id, name=name, from_bus_id=1, to_bus_id=2, reactance_pu=0.1, thermal_limit_mw=100.0)
end

function make_pumping_plant(id=1; name="PP$(id)")
    PumpingPlant(
        id=id, name=name, submarket_id=1, bus_id=1,
        downstream_hydro_id=1, upstream_hydro_id=2,
        min_pumping_hm3=0.0, max_pumping_hm3=50.0,
        specific_consumption_mw_per_m3s=0.01
    )
end

function make_renewable_plant(id=1; name="RP$(id)")
    RenewablePlant(id=id, name=name, submarket_id=1, bus_id=1, available_generation_mw=[100.0])
end

function make_study_horizon()
    StudyHorizon(
        periods=1, period_duration_hours=1.0,
        original_periods=1, original_period_durations_hours=[1.0],
        internal_to_original_period=[1], internal_subperiod_index=[1]
    )
end

function make_minimal_system(;
    submarkets=[make_submarket()],
    buses=[make_bus()],
    branches=Branch[],
    thermal_plants=ThermalPlant[],
    hydro_plants=HydroPlant[],
    pumping_plants=PumpingPlant[],
    renewable_plants=RenewablePlant[],
    interchange_limits=InterchangeLimit[],
    residual_costs=ResidualCost[],
    future_cost_cuts=FutureCostCut[],
    operational_limits=OperationalLimit[],
    inflow_history=InflowHistoryRow[],
    ton_residual_enabled=false,
    future_cost_enabled=false,
    fpha_enabled=false
)
    System(
        horizon=make_study_horizon(),
        thermal_unit_commitment_enabled=false,
        hydro_unit_commitment_enabled=false,
        ton_residual_enabled=ton_residual_enabled,
        fpha_enabled=fpha_enabled,
        future_cost_enabled=future_cost_enabled,
        residual_costs=residual_costs,
        future_cost_cuts=future_cost_cuts,
        submarkets=submarkets,
        interchange_limits=interchange_limits,
        operational_limits=operational_limits,
        buses=buses,
        branches=branches,
        thermal_plants=thermal_plants,
        hydro_plants=hydro_plants,
        pumping_plants=pumping_plants,
        renewable_plants=renewable_plants,
        inflow_history=inflow_history
    )
end

@testset "Core Module Tests" begin

    @testset "Type Aliases" begin
        @test SubmarketId === Int
        @test BusId === Int
        @test BranchId === Int
        @test ThermalPlantId === Int
        @test ThermalUnitId === Int
        @test HydroPlantId === Int
        @test HydroGroupId === Int
        @test HydroUnitId === Int
        @test PumpingPlantId === Int
        @test RenewablePlantId === Int
    end

    @testset "TurbineType Enum" begin
        @test Francis isa TurbineType
        @test Kaplan isa TurbineType
        @test Unknown isa TurbineType
        @test length(instances(TurbineType)) == 3
    end

    @testset "turbine_alpha Function" begin
        @test turbine_alpha(Francis) ≈ 0.5
        @test turbine_alpha(Kaplan) ≈ 0.2
        @test turbine_alpha(Unknown) ≈ 0.5
    end

    @testset "OperationalLimitVariable Enum" begin
        @test Generation isa OperationalLimitVariable
        @test Spillage isa OperationalLimitVariable
        @test Volume isa OperationalLimitVariable
        @test Defluence isa OperationalLimitVariable
        @test Turbining isa OperationalLimitVariable
        @test Diversion isa OperationalLimitVariable
        @test Pumping isa OperationalLimitVariable
        @test length(instances(OperationalLimitVariable)) == 7
    end

    @testset "ThermalInitialCondition" begin
        @testset "Construction" begin
            cond = make_thermal_initial_condition()
            @test cond.is_on == true
            @test cond.generation_mw == 50.0
            @test cond.time_in_state == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_thermal_initial_condition()) === nothing
        end
        @testset "Validation - Negative generation" begin
            cond = ThermalInitialCondition(
                is_on=true, generation_mw=-10.0, time_in_state=1,
                time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
            )
            @test_throws ArgumentError validate!(cond)
        end
        @testset "Validation - Negative time_in_state" begin
            cond = ThermalInitialCondition(
                is_on=true, generation_mw=50.0, time_in_state=-1,
                time_in_ramp=0, is_ramping_up=false, is_ramping_down=false
            )
            @test_throws ArgumentError validate!(cond)
        end
    end

    @testset "ThermalUnit" begin
        @testset "Construction" begin
            unit = make_thermal_unit()
            @test unit.id == 1
            @test unit.name == "TU1"
            @test unit.min_generation_mw == 0.0
        end
        @testset "Validation - Valid" begin
            @test validate!(make_thermal_unit()) === nothing
        end
        @testset "Validation - Empty name" begin
            unit = ThermalUnit(
                id=1, name="", min_generation_mw=0.0, max_generation_mw=100.0,
                startup_trajectory_mw=[50.0], shutdown_trajectory_mw=[50.0],
                min_up_time=1, min_down_time=1, startup_cost=1000.0, shutdown_cost=0.0,
                variable_cost_per_mwh=50.0, initial_condition=make_thermal_initial_condition()
            )
            @test_throws ArgumentError validate!(unit)
        end
        @testset "Validation - min > max generation" begin
            unit = ThermalUnit(
                id=1, name="TU", min_generation_mw=100.0, max_generation_mw=50.0,
                startup_trajectory_mw=[50.0], shutdown_trajectory_mw=[50.0],
                min_up_time=1, min_down_time=1, startup_cost=1000.0, shutdown_cost=0.0,
                variable_cost_per_mwh=50.0, initial_condition=make_thermal_initial_condition()
            )
            @test_throws ArgumentError validate!(unit)
        end
    end

    @testset "ThermalPlant" begin
        @testset "Construction" begin
            plant = make_thermal_plant()
            @test plant.id == 1
            @test plant.name == "TP1"
            @test length(plant.units) == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_thermal_plant()) === nothing
        end
        @testset "Validation - Empty name" begin
            plant = ThermalPlant(id=1, name="", submarket_id=1, bus_id=1, units=[make_thermal_unit()])
            @test_throws ArgumentError validate!(plant)
        end
        @testset "Validation - Empty units" begin
            plant = ThermalPlant(id=1, name="TP", submarket_id=1, bus_id=1, units=ThermalUnit[])
            @test_throws ArgumentError validate!(plant)
        end
    end

    @testset "Reservoir" begin
        @testset "Construction" begin
            res = make_reservoir()
            @test res.min_volume_hm3 == 0.0
            @test res.max_volume_hm3 == 100.0
        end
        @testset "Validation - Valid" begin
            @test validate!(make_reservoir()) === nothing
        end
        @testset "Validation - min > max" begin
            res = Reservoir(min_volume_hm3=100.0, max_volume_hm3=50.0, initial_volume_hm3=75.0)
            @test_throws ArgumentError validate!(res)
        end
        @testset "Validation - initial out of bounds" begin
            res = Reservoir(min_volume_hm3=0.0, max_volume_hm3=100.0, initial_volume_hm3=150.0)
            @test_throws ArgumentError validate!(res)
        end
    end

    @testset "HydroInitialCondition" begin
        @testset "Construction" begin
            cond = make_hydro_initial_condition()
            @test cond.is_on == true
        end
        @testset "Validation - Valid" begin
            @test validate!(make_hydro_initial_condition()) === nothing
        end
        @testset "Validation - Negative generation" begin
            cond = HydroInitialCondition(is_on=true, generation_mw=-10.0, time_in_state=1)
            @test_throws ArgumentError validate!(cond)
        end
    end

    @testset "HydroUnit" begin
        @testset "Construction" begin
            unit = make_hydro_unit()
            @test unit.id == 1
            @test unit.name == "HU1"
        end
        @testset "Validation - Valid" begin
            @test validate!(make_hydro_unit()) === nothing
        end
        @testset "Validation - Empty name" begin
            unit = HydroUnit(
                id=1, name="", min_generation_mw=0.0, max_generation_mw=100.0,
                max_turbining_hm3=50.0, effective_head_m=100.0,
                initial_condition=make_hydro_initial_condition()
            )
            @test_throws ArgumentError validate!(unit)
        end
    end

    @testset "HydroGroup" begin
        @testset "Construction" begin
            group = make_hydro_group()
            @test group.id == 1
            @test length(group.units) == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_hydro_group()) === nothing
        end
        @testset "Validation - Empty name" begin
            group = HydroGroup(id=1, name="", units=[make_hydro_unit()])
            @test_throws ArgumentError validate!(group)
        end
        @testset "Validation - Empty units" begin
            group = HydroGroup(id=1, name="HG", units=HydroUnit[])
            @test_throws ArgumentError validate!(group)
        end
    end

    @testset "HydroPlant" begin
        @testset "Construction" begin
            plant = make_hydro_plant()
            @test plant.id == 1
            @test plant.name == "HP1"
        end
        @testset "Validation - Valid" begin
            @test validate!(make_hydro_plant()) === nothing
        end
        @testset "Validation - Empty name" begin
            plant = HydroPlant(
                id=1, name="", submarket_id=1, bus_id=1,
                upstream_plant_ids=Int[], downstream_plant_id=nothing,
                diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
                reservoir=make_reservoir(),
                natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
                spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0,
                specific_productivity_mw_per_m3s=0.01, hydraulic_loss_m=nothing, efficiency=nothing,
                fpha_segments=HydroFphaSegment[], groups=[make_hydro_group()],
                turbine_type=Francis, volume_level_table=nothing, tailrace_coefficients=nothing
            )
            @test_throws ArgumentError validate!(plant)
        end
    end

    @testset "Submarket" begin
        @testset "Construction" begin
            sm = make_submarket()
            @test sm.id == 1
            @test sm.name == "SM1"
        end
        @testset "Validation - Valid" begin
            @test validate!(make_submarket()) === nothing
        end
        @testset "Validation - Empty name" begin
            sm = Submarket(id=1, name="", demand_mw=[100.0])
            @test_throws ArgumentError validate!(sm)
        end
    end

    @testset "Bus" begin
        @testset "Construction" begin
            bus = make_bus()
            @test bus.id == 1
            @test bus.angle_reference == true
        end
        @testset "Validation - Valid" begin
            @test validate!(make_bus()) === nothing
        end
        @testset "Validation - Empty name" begin
            bus = Bus(id=1, name="", submarket_id=1, demand_mw=[50.0], angle_reference=true)
            @test_throws ArgumentError validate!(bus)
        end
    end

    @testset "Branch" begin
        @testset "Construction" begin
            br = make_branch()
            @test br.id == 1
            @test br.from_bus_id == 1
            @test br.to_bus_id == 2
        end
        @testset "Validation - Valid" begin
            @test validate!(make_branch()) === nothing
        end
        @testset "Validation - Empty name" begin
            br = Branch(id=1, name="", from_bus_id=1, to_bus_id=2, reactance_pu=0.1, thermal_limit_mw=100.0)
            @test_throws ArgumentError validate!(br)
        end
        @testset "Validation - Same from/to bus" begin
            br = Branch(id=1, name="BR", from_bus_id=1, to_bus_id=1, reactance_pu=0.1, thermal_limit_mw=100.0)
            @test_throws ArgumentError validate!(br)
        end
    end

    @testset "PumpingPlant" begin
        @testset "Construction" begin
            pp = make_pumping_plant()
            @test pp.id == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_pumping_plant()) === nothing
        end
        @testset "Validation - Empty name" begin
            pp = PumpingPlant(
                id=1, name="", submarket_id=1, bus_id=1,
                downstream_hydro_id=1, upstream_hydro_id=2,
                min_pumping_hm3=0.0, max_pumping_hm3=50.0,
                specific_consumption_mw_per_m3s=0.01
            )
            @test_throws ArgumentError validate!(pp)
        end
        @testset "Validation - min > max pumping" begin
            pp = PumpingPlant(
                id=1, name="PP", submarket_id=1, bus_id=1,
                downstream_hydro_id=1, upstream_hydro_id=2,
                min_pumping_hm3=100.0, max_pumping_hm3=50.0,
                specific_consumption_mw_per_m3s=0.01
            )
            @test_throws ArgumentError validate!(pp)
        end
    end

    @testset "RenewablePlant" begin
        @testset "Construction" begin
            rp = make_renewable_plant()
            @test rp.id == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_renewable_plant()) === nothing
        end
        @testset "Validation - Empty name" begin
            rp = RenewablePlant(id=1, name="", submarket_id=1, bus_id=1, available_generation_mw=[100.0])
            @test_throws ArgumentError validate!(rp)
        end
    end

    @testset "StudyHorizon" begin
        @testset "Construction" begin
            h = make_study_horizon()
            @test h.periods == 1
        end
        @testset "Validation - Valid" begin
            @test validate!(make_study_horizon()) === nothing
        end
        @testset "Validation - Non-positive periods" begin
            h = StudyHorizon(
                periods=0, period_duration_hours=1.0,
                original_periods=1, original_period_durations_hours=[1.0],
                internal_to_original_period=[1], internal_subperiod_index=[1]
            )
            @test_throws ArgumentError validate!(h)
        end
    end

    @testset "System Validation - Valid System" begin
        sys = make_minimal_system()
        @test validate!(sys) === nothing
    end

    @testset "System Validation - Duplicate IDs" begin
        @testset "Duplicate Submarket IDs" begin
            sys = make_minimal_system(submarkets=[
                make_submarket(1), make_submarket(1, name="SM2")
            ])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Duplicate Bus IDs" begin
            sys = make_minimal_system(buses=[
                make_bus(1), make_bus(1, name="B2", angle_reference=false)
            ])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Duplicate ThermalPlant IDs" begin
            sys = make_minimal_system(thermal_plants=[
                make_thermal_plant(1), make_thermal_plant(1, name="TP2")
            ])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Duplicate HydroPlant IDs" begin
            sys = make_minimal_system(hydro_plants=[
                make_hydro_plant(1), make_hydro_plant(1, name="HP2")
            ])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "System Validation - Cross-References" begin
        @testset "Bus references invalid submarket" begin
            sys = make_minimal_system(
                buses=[Bus(id=1, name="B1", submarket_id=999, demand_mw=[50.0], angle_reference=true)]
            )
            @test_throws ArgumentError validate!(sys)
        end
        @testset "ThermalPlant references invalid bus" begin
            tp = ThermalPlant(id=1, name="TP", submarket_id=1, bus_id=999, units=[make_thermal_unit()])
            sys = make_minimal_system(thermal_plants=[tp])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "HydroPlant references invalid submarket" begin
            hp = HydroPlant(
                id=1, name="HP", submarket_id=999, bus_id=1,
                upstream_plant_ids=Int[], downstream_plant_id=nothing,
                diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
                reservoir=make_reservoir(),
                natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
                spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0,
                specific_productivity_mw_per_m3s=0.01, hydraulic_loss_m=nothing, efficiency=nothing,
                fpha_segments=HydroFphaSegment[], groups=[make_hydro_group()],
                turbine_type=Francis, volume_level_table=nothing, tailrace_coefficients=nothing
            )
            sys = make_minimal_system(hydro_plants=[hp])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "System Validation - Cascade Consistency" begin
        hp1 = make_hydro_plant(1, downstream_plant_id=2)
        hp2 = make_hydro_plant(2, name="HP2")  # does not list 1 as upstream
        sys = make_minimal_system(hydro_plants=[hp1, hp2])
        @test_throws ArgumentError validate!(sys)
    end

    @testset "System Validation - Diversion Consistency" begin
        hp1 = HydroPlant(
            id=1, name="HP1", submarket_id=1, bus_id=1,
            upstream_plant_ids=Int[], downstream_plant_id=nothing,
            diversion_upstream_plant_ids=Int[], diversion_plant_id=2,
            reservoir=make_reservoir(),
            natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
            spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0,
            specific_productivity_mw_per_m3s=0.01, hydraulic_loss_m=nothing, efficiency=nothing,
            fpha_segments=HydroFphaSegment[], groups=[make_hydro_group(1)],
            turbine_type=Francis, volume_level_table=nothing, tailrace_coefficients=nothing
        )
        hp2 = make_hydro_plant(2, name="HP2")  # does not list 1 in diversion_upstream_plant_ids
        sys = make_minimal_system(hydro_plants=[hp1, hp2])
        @test_throws ArgumentError validate!(sys)
    end

    @testset "System Validation - Horizon Consistency" begin
        @testset "Submarket demand length mismatch" begin
            sm = Submarket(id=1, name="SM", demand_mw=[100.0, 200.0])  # 2 periods, but horizon has 1
            sys = make_minimal_system(submarkets=[sm])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Bus demand length mismatch" begin
            bus = Bus(id=1, name="B", submarket_id=1, demand_mw=[50.0, 60.0], angle_reference=true)
            sys = make_minimal_system(buses=[bus])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "System Validation - Slack Bus" begin
        @testset "Zero slack buses" begin
            sys = make_minimal_system(buses=[make_bus(angle_reference=false)])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Multiple slack buses" begin
            sys = make_minimal_system(buses=[
                make_bus(1, angle_reference=true),
                make_bus(2, name="B2", angle_reference=true)
            ])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "System Validation - TON Residual" begin
        sys = make_minimal_system(ton_residual_enabled=true)  # no residual_costs
        @test_throws ArgumentError validate!(sys)
    end

    @testset "System Validation - FCF" begin
        @testset "Future cost enabled but no cuts" begin
            sys = make_minimal_system(future_cost_enabled=true)
            @test_throws ArgumentError validate!(sys)
        end
        @testset "FCF coefficient count mismatch" begin
            hp = make_hydro_plant()
            cut = FutureCostCut(
                stage_id=1, cut_id=1, slot_index=1, iteration=1, forward_pass_index=1,
                intercept=1000.0, coefficients=[1.0, 2.0], is_active=true  # 2 coeffs, 1 plant
            )
            sys = make_minimal_system(hydro_plants=[hp], future_cost_enabled=true, future_cost_cuts=[cut])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "System Validation - FPHA" begin
        hp = HydroPlant(
            id=1, name="HP", submarket_id=1, bus_id=1,
            upstream_plant_ids=Int[], downstream_plant_id=nothing,
            diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
            reservoir=make_reservoir(),
            natural_inflow_hm3=[10.0], water_withdrawal_hm3=[0.0],
            spillage_cost_per_hm3=0.0, turbining_cost_per_hm3=0.0,
            specific_productivity_mw_per_m3s=0.01, hydraulic_loss_m=nothing, efficiency=nothing,
            fpha_segments=HydroFphaSegment[],  # empty but has groups
            groups=[make_hydro_group()],
            turbine_type=Francis, volume_level_table=nothing, tailrace_coefficients=nothing
        )
        sys = make_minimal_system(hydro_plants=[hp], fpha_enabled=true)
        @test_throws ArgumentError validate!(sys)
    end

    @testset "System Validation - Operational Limits" begin
        @testset "Invalid target reference" begin
            ol = OperationalLimit(
                target=ThermalPlantTarget(999), plant_name="Unknown",
                variable=Generation, start_period=1, end_period=1,
                lower_bound=0.0, upper_bound=100.0
            )
            sys = make_minimal_system(operational_limits=[ol])
            @test_throws ArgumentError validate!(sys)
        end
        @testset "Invalid period range" begin
            tp = make_thermal_plant()
            ol = OperationalLimit(
                target=ThermalPlantTarget(1), plant_name="TP",
                variable=Generation, start_period=0, end_period=1,
                lower_bound=0.0, upper_bound=100.0
            )
            sys = make_minimal_system(thermal_plants=[tp], operational_limits=[ol])
            @test_throws ArgumentError validate!(sys)
        end
    end

    @testset "Module Exports" begin
        @test @isdefined(SubmarketId)
        @test @isdefined(ThermalPlant)
        @test @isdefined(HydroPlant)
        @test @isdefined(System)
        @test @isdefined(validate!)
        @test @isdefined(turbine_alpha)
        @test @isdefined(Francis)
        @test @isdefined(Generation)
        @test @isdefined(OperationalLimitTarget)
        @test @isdefined(ThermalPlantTarget)
    end

end
