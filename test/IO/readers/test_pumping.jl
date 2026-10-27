using Test
using LabDessem
using LabDessem.IO

const FIXTURE_DIR = joinpath(@__DIR__, "..", "fixtures")

@testset "Pumping Reader" begin
    mkpath(FIXTURE_DIR)

    function make_hydro_plants()
        [
            LabDessem.Core.HydroPlant(
                id=0, name="UHE-A", submarket_id=1, bus_id=1,
                upstream_plant_ids=Int[], downstream_plant_id=nothing,
                diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
                reservoir=LabDessem.Core.Reservoir(100.0, 200.0, 150.0),
                natural_inflow_hm3=[0.0], water_withdrawal_hm3=[0.0],
                spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.1,
                specific_productivity_mw_per_m3s=1.0, hydraulic_loss_m=nothing,
                efficiency=nothing, fpha_segments=LabDessem.Core.HydroFphaSegment[],
                groups=LabDessem.Core.HydroGroup[], turbine_type=LabDessem.Core.Francis,
                volume_level_table=nothing, tailrace_coefficients=nothing
            ),
            LabDessem.Core.HydroPlant(
                id=1, name="UHE-B", submarket_id=1, bus_id=2,
                upstream_plant_ids=Int[], downstream_plant_id=nothing,
                diversion_upstream_plant_ids=Int[], diversion_plant_id=nothing,
                reservoir=LabDessem.Core.Reservoir(50.0, 100.0, 75.0),
                natural_inflow_hm3=[0.0], water_withdrawal_hm3=[0.0],
                spillage_cost_per_hm3=0.1, turbining_cost_per_hm3=0.1,
                specific_productivity_mw_per_m3s=1.0, hydraulic_loss_m=nothing,
                efficiency=nothing, fpha_segments=LabDessem.Core.HydroFphaSegment[],
                groups=LabDessem.Core.HydroGroup[], turbine_type=LabDessem.Core.Kaplan,
                volume_level_table=nothing, tailrace_coefficients=nothing
            )
        ]
    end

    function make_submarkets()
        [
            LabDessem.Core.Submarket(id=1, name="Fic1", demand_mw=[0.0]),
            LabDessem.Core.Submarket(id=2, name="Fic2", demand_mw=[0.0])
        ]
    end

    @testset "basic reading" begin
        hydros = make_hydro_plants()
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_usie_basic.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Submercado;Jusante;Montante;QbombMin.m3/s;QbombMax.m3/s;Consumo.mw/m3s;Barra\n")
            write(io, "0;USIE-1;Fic1;0;1;10;100;1.5;1\n")
        end
        
        plants = read_pumping_plants(cad_path, hydros, sbms, 0.5, false)
        
        @test length(plants) == 1
        @test plants[1].id == 0
        @test plants[1].name == "USIE-1"
        @test plants[1].downstream_hydro_id == 0
        @test plants[1].upstream_hydro_id == 1
        @test plants[1].min_pumping_hm3 ≈ flow_m3s_to_hm3(10.0, 0.5)
        @test plants[1].max_pumping_hm3 ≈ flow_m3s_to_hm3(100.0, 0.5)
        @test plants[1].specific_consumption_mw_per_m3s == 1.5
        
        rm(cad_path)
    end

    @testset "unknown hydro reference" begin
        hydros = make_hydro_plants()
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_usie_bad.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Submercado;Jusante;Montante;QbombMin.m3/s;QbombMax.m3/s;Consumo.mw/m3s;Barra\n")
            write(io, "0;USIE-1;Fic1;99;1;10;100;1.5;1\n")
        end
        
        @test_throws ArgumentError read_pumping_plants(cad_path, hydros, sbms, 0.5, false)
        
        rm(cad_path)
    end

    @testset "empty file" begin
        hydros = make_hydro_plants()
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_usie_empty.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Submercado;Jusante;Montante;QbombMin.m3/s;QbombMax.m3/s;Consumo.mw/m3s;Barra\n")
        end
        
        plants = read_pumping_plants(cad_path, hydros, sbms, 0.5, false)
        @test isempty(plants)
        
        rm(cad_path)
    end

    @testset "type inference" begin
        hydros = make_hydro_plants()
        sbms = make_submarkets()
        
        cad_path = joinpath(FIXTURE_DIR, "cad_usie_infer.csv")
        open(cad_path, "w") do io
            write(io, "Codigo;Nome;Submercado;Jusante;Montante;QbombMin.m3/s;QbombMax.m3/s;Consumo.mw/m3s;Barra\n")
            write(io, "0;USIE-1;Fic1;0;1;10;100;1.5;1\n")
        end
        
        @test @inferred(read_pumping_plants(cad_path, hydros, sbms, 0.5, false)) isa Vector{LabDessem.Core.PumpingPlant}
        
        rm(cad_path)
    end
end
