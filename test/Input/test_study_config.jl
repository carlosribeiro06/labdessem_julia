using Test
using LabDessem
using LabDessem.Input

const TEST_DATA_DIR = joinpath(@__DIR__, "fixtures")

@testset "Study Config" begin

    @testset "FphaOption parsing" begin
        @test LabDessem.Input.parse_fpha_option("constant_productivity") == ConstantProductivity
        @test LabDessem.Input.parse_fpha_option("precomputed") == Precomputed
        @test LabDessem.Input.parse_fpha_option("computed") == Computed
        @test_throws ArgumentError LabDessem.Input.parse_fpha_option("invalid")
        err = try LabDessem.Input.parse_fpha_option("invalid") catch e e end
        @test occursin("constant_productivity", err.msg)
    end

    @testset "read_study_config" begin
        mkpath(TEST_DATA_DIR)
        
        @testset "minimal valid" begin
            json_path = joinpath(TEST_DATA_DIR, "minimal_config.json")
            open(json_path, "w") do io
                write(io, """{"opcao_execucao": 1}""")
            end
            cfg = read_study_config(json_path)
            @test cfg.opcao_execucao == 1
            @test cfg.rede == false
            @test cfg.uct == false
            @test cfg.uch == false
            @test cfg.fpha == ConstantProductivity
            @test cfg.fcf == false
            @test cfg.ton_residual == false
            @test cfg.engmax == false
            rm(json_path)
        end

        @testset "all fields" begin
            json_path = joinpath(TEST_DATA_DIR, "full_config.json")
            open(json_path, "w") do io
                write(io, """{
                    "opcao_execucao": 2,
                    "rede": 1,
                    "UCT": 1,
                    "UCH": 1,
                    "FPHA": "precomputed",
                    "FCF": 1,
                    "TON_Residual": 1,
                    "EngMax": 1
                }""")
            end
            cfg = read_study_config(json_path)
            @test cfg.opcao_execucao == 2
            @test cfg.rede == true
            @test cfg.uct == true
            @test cfg.uch == true
            @test cfg.fpha == Precomputed
            @test cfg.fcf == true
            @test cfg.ton_residual == true
            @test cfg.engmax == true
            rm(json_path)
        end

        @testset "missing required field" begin
            json_path = joinpath(TEST_DATA_DIR, "missing_field.json")
            open(json_path, "w") do io
                write(io, """{"rede": 1}""")
            end
            @test_throws ArgumentError read_study_config(json_path)
            err = try read_study_config(json_path) catch e e end
            @test occursin("opcao_execucao", err.msg)
            rm(json_path)
        end

        @testset "invalid fpha option" begin
            json_path = joinpath(TEST_DATA_DIR, "invalid_fpha.json")
            open(json_path, "w") do io
                write(io, """{"opcao_execucao": 1, "FPHA": "invalid"}""")
            end
            @test_throws ArgumentError read_study_config(json_path)
            rm(json_path)
        end

        @testset "missing file" begin
            @test_throws ArgumentError read_study_config("/nonexistent.json")
        end

        @testset "type inference" begin
            json_path = joinpath(TEST_DATA_DIR, "type_test.json")
            open(json_path, "w") do io
                write(io, """{"opcao_execucao": 1}""")
            end
            @test @inferred(read_study_config(json_path)) isa StudyConfig
            rm(json_path)
        end
    end

    @testset "helper functions" begin
        cfg_const = StudyConfig(1, false, false, false, ConstantProductivity, false, false, false)
        cfg_pre = StudyConfig(1, false, false, false, Precomputed, false, false, false)
        cfg_comp = StudyConfig(1, false, false, false, Computed, false, false, false)
        
        @test is_fpha_enabled(cfg_const) == false
        @test is_fpha_enabled(cfg_pre) == true
        @test is_fpha_enabled(cfg_comp) == true
        
        @test is_fpha_precomputed(cfg_const) == false
        @test is_fpha_precomputed(cfg_pre) == true
        @test is_fpha_precomputed(cfg_comp) == false
        
        @test @inferred(is_fpha_enabled(cfg_const)) isa Bool
        @test @inferred(is_fpha_precomputed(cfg_const)) isa Bool
    end

    @testset "integration with real file" begin
        cfg = read_study_config(joinpath(fixture_inputs(), "study_config.json"))
        @test cfg.opcao_execucao == 2
        @test cfg.rede == true
        @test cfg.uct == true
        @test cfg.uch == false
        @test cfg.fpha == ConstantProductivity
        @test cfg.fcf == true
        @test cfg.engmax == true
    end
end
