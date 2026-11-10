using Test

const GOLDEN_ONS_HEADER = """
ONS - Operador Nacional do Sistema Eletrico
LabDessem

Descricao das colunas:
Etapa: etapa do processo iterativo
Observacao: texto; com ponto e virgula
ValorFuncaoObjetivo: valor da funcao objetivo em R\$

"""

const GOLDEN_ONS_HEADER_ITER = """
ONS - Operador Nacional do Sistema Eletrico
LabDessem

Descricao das colunas:
Etapa: etapa do processo iterativo
ValorFuncaoObjetivo: valor da funcao objetivo em R\$

"""

function golden_compare(otext::String, jtext::String; kwargs...)
    mktempdir() do dir
        op, jp = joinpath(dir, "o.csv"), joinpath(dir, "j.csv")
        write(op, otext)
        write(jp, jtext)
        compare_result_file(op, jp; kwargs...)
    end
end

golden_cell(o, j; col = "Valor") = golden_compare("$col\n$o\n", "$col\n$j\n")

golden_kinds(ms) = [m.kind for m in ms]

@testset "Golden comparator" begin
    @testset "Mismatch" begin
        @test fieldtypes(Mismatch) == (String, Int, String, String, String, Symbol)
        @test DEFAULT_EXCLUDED == Set(["TempoResolucaoSeg", "NumeroRestricoes", "NumeroVariaveis"])
    end

    @testset "read_result_table" begin
        mktempdir() do dir
            path = joinpath(dir, "t.csv")

            write(path, GOLDEN_ONS_HEADER * "Etapa;Observacao;ValorFuncaoObjetivo\nMILP; CAMARGOS     ;1.5\nLP;b;2.5\n")
            cols, rows = read_result_table(path)
            @test cols == ["Etapa", "Observacao", "ValorFuncaoObjetivo"]
            @test rows == [["MILP", " CAMARGOS     ", "1.5"], ["LP", "b", "2.5"]]

            write(path, "A;B\n1;2\n")
            @test read_result_table(path) == (["A", "B"], [["1", "2"]])

            write(path, "A;B\r\n1;2\r\n3;4\r")
            @test read_result_table(path) == (["A", "B"], [["1", "2"], ["3", "4"]])

            write(path, "A;B\n1;\n")
            @test read_result_table(path) == (["A", "B"], [["1", ""]])

            write(path, "A;B\n")
            @test read_result_table(path) == (["A", "B"], Vector{String}[])

            write(path, "ONS - Operador Nacional do Sistema Eletrico\nLabDessem\n\nDescricao das colunas:\nA: a\n\n")
            @test_throws ErrorException read_result_table(path)
            @test_throws "t.csv" read_result_table(path)

            write(path, "ONS - Operador Nacional do Sistema Eletrico\nLabDessem\n")
            @test_throws ErrorException read_result_table(path)

            write(path, "")
            @test_throws ErrorException read_result_table(path)

            @test_throws SystemError read_result_table(joinpath(dir, "missing.csv"))
        end
    end

    @testset "header block" begin
        body = "Etapa;Observacao;ValorFuncaoObjetivo\nMILP;x;1.5\n"
        @test isempty(golden_compare(GOLDEN_ONS_HEADER * body, body))
        @test isempty(golden_compare(body, GOLDEN_ONS_HEADER * body))
        @test isempty(golden_compare(GOLDEN_ONS_HEADER * body, replace(GOLDEN_ONS_HEADER, "\n" => "\r\n") * replace(body, "\n" => "\r\n")))
    end

    @testset "numeric tolerance from oracle decimals" begin
        @testset "d = 6 (spec example)" begin
            @test isempty(golden_cell("1.234567", "1.2345684"))
            @test golden_cell("1.234567", "1.2345690") ==
                  [Mismatch("o.csv", 1, "Valor", "1.234567", "1.2345690", :numeric)]
        end
        @testset "d = $d" for (d, o, ok, bad) in [
            (3, "0.001", "0.0024", "0.0026"),
            (4, "0.0001", "0.00024", "0.00026"),
            (9, "0.000000001", "0.000000002", "0.000000003"),
        ]
            @test isempty(golden_cell(o, ok))
            @test golden_kinds(golden_cell(o, bad)) == [:numeric]
        end
        @testset "rtol dominates large values" begin
            @test isempty(golden_cell("1234567.891000", "1234567.9"))
            @test golden_kinds(golden_cell("1234567.891000", "1234568.1")) == [:numeric]
        end
        @testset "padded oracle cell counts decimals on trimmed text" begin
            @test isempty(golden_cell(" 0.001 ", "0.0024"))
        end
        @testset "exponent uses atol = 0" begin
            @test isempty(golden_cell("1.5e-5", "1.5e-5"))
            @test golden_kinds(golden_cell("1.5e-5", "1.50001e-5")) == [:numeric]
            @test golden_kinds(golden_cell("1.5E-5", "1.50001E-5")) == [:numeric]
        end
        @testset "-0.0 equals 0.0" begin
            @test isempty(golden_cell("0.000000", "-0.000000"))
            @test isempty(golden_cell("-0.000000", "0.000000"))
            @test isempty(golden_cell("-0.000000", "0"))
        end
    end

    @testset "text cells" begin
        @test golden_cell("NaN", "NaN") |> isempty
        @test golden_kinds(golden_cell("NaN", "nan")) == [:key]
        @test golden_cell("inf", "inf") |> isempty
        @test golden_kinds(golden_cell("inf", "-inf")) == [:key]
        @test golden_kinds(golden_cell("1.5", "NaN")) == [:numeric]
        @test golden_kinds(golden_cell("1", "2")) == [:key]
        @test golden_kinds(golden_cell("1", "1.0")) == [:key]
        @test golden_kinds(golden_cell("OPTIMAL", "INFEASIBLE")) == [:key]
        @test golden_kinds(golden_cell("1.5", "OPTIMAL")) == [:key]
        @test golden_kinds(golden_cell(" CAMARGOS     ", "CAMARGOS")) == [:key]
        @test golden_cell("CAMARGOS", "CAMARGOS ") ==
              [Mismatch("o.csv", 1, "Valor", "CAMARGOS", "CAMARGOS ", :key)]
        @test isempty(golden_cell(" CAMARGOS     ", " CAMARGOS     "))
    end

    @testset "exclusions and ValorFuncaoObjetivo" begin
        iter(obj, nr, nv, t) = GOLDEN_ONS_HEADER_ITER *
            "Etapa;Iteracao;NumeroRestricoes;NumeroVariaveis;ValorFuncaoObjetivo;StatusSolucao;TempoResolucaoSeg\n" *
            "MILP;1;$nr;$nv;$obj;OPTIMAL;$t\n"
        oracle = iter("4497639.836362", "7366", "2885", "1.009003")

        @test isempty(golden_compare(oracle, iter("4497639.836362", "7000", "2000", "9.5")))
        @test golden_compare(oracle, iter("4497640.4", "7366", "2885", "1.009003")) ==
              [Mismatch("o.csv", 1, "ValorFuncaoObjetivo", "4497639.836362", "4497640.4", :numeric)]
        @test isempty(golden_compare(oracle, iter("4497640.2", "7366", "2885", "1.009003")))

        ms = golden_compare(oracle, iter("4497639.836362", "7000", "2000", "9.5"); excluded_columns = Set{String}())
        @test [(m.column, m.kind) for m in ms] ==
              [("NumeroRestricoes", :key), ("NumeroVariaveis", :key), ("TempoResolucaoSeg", :numeric)]

        @test golden_kinds(golden_cell("0.000001", "0.000002"; col = "ValorFuncaoObjetivo")) == [:numeric]
        @test isempty(golden_cell("0.000001", "0.000002"))
    end

    @testset "file-level mismatches" begin
        @test golden_compare("A;B\n1;2\n", "A;C\n1;2\n") ==
              [Mismatch("o.csv", 0, "", "A;B", "A;C", :header)]
        @test golden_compare("A;B\n1;2\n", "A;B\n1;2\n3;4\n") ==
              [Mismatch("o.csv", 0, "", "1", "2", :row_count)]
        @test golden_compare("A;B\n1;2\n", "A;C\n1;2\n3;4\n") ==
              [Mismatch("o.csv", 0, "", "A;B", "A;C", :header)]
        @test golden_compare("A;B\n1;2\n", "A;B\n1;2;3\n") ==
              [Mismatch("o.csv", 1, "", "1;2", "1;2;3", :key)]
    end

    @testset "ordering by row then column" begin
        ms = golden_compare("A;B;C\n1;x;3.0\n4;y;6.0\n", "A;B;C\n2;z;9.0\n4;w;6.0\n")
        @test [(m.row, m.column, m.kind) for m in ms] ==
              [(1, "A", :key), (1, "B", :key), (1, "C", :numeric), (2, "B", :key)]
    end

    @testset "compare_result_dirs" begin
        mktempdir() do dir
            od, jd = joinpath(dir, "o"), joinpath(dir, "j")
            mkdir(od)
            mkdir(jd)
            for (d, name, text) in [
                (od, "a.csv", "A\n1\n"), (jd, "a.csv", "A\n1\n"),
                (od, "b.csv", "A\n1\n"), (jd, "b.csv", "A\n2\n"),
                (od, "c_only_oracle.csv", "A\n1\n"),
                (jd, "d_only_julia.csv", "A\n1\n"),
                (jd, "resultado_fpha_computed.csv", "A\n1\n"),
            ]
                write(joinpath(d, name), text)
            end

            @test compare_result_dirs(od, jd) == [
                Mismatch("b.csv", 1, "A", "1", "2", :key),
                Mismatch("c_only_oracle.csv", 0, "", "present", "absent", :missing_file),
                Mismatch("d_only_julia.csv", 0, "", "absent", "present", :extra_file),
                Mismatch("resultado_fpha_computed.csv", 0, "", "absent", "present", :extra_file),
            ]
            @test compare_result_dirs(od, jd; excluded_files = ["resultado_fpha_computed.csv", "c_only_oracle.csv"]) == [
                Mismatch("b.csv", 1, "A", "1", "2", :key),
                Mismatch("d_only_julia.csv", 0, "", "absent", "present", :extra_file),
            ]
        end
    end

    @testset "24Barras fixture" begin
        oracle_dir = joinpath(FIXTURES_DIR, "24Barras", "oracle", "RESULTADOS")
        expected_dir = joinpath(FIXTURES_DIR, "24Barras", "expected")
        @test length(readdir(oracle_dir)) == 13
        @test isempty(compare_result_dirs(oracle_dir, expected_dir))

        mktempdir() do dir
            dst = joinpath(dir, "expected")
            cp(expected_dir, dst)
            path = joinpath(dst, "resultado_rede.csv")
            lines = readlines(path)
            cells = String.(split(lines[2], ';'))
            @test cells[4] == "1"
            cells[4] = "2"
            lines[2] = join(cells, ';')
            write(path, join(lines, '\n') * "\n")

            @test compare_result_dirs(oracle_dir, dst) ==
                  [Mismatch("resultado_rede.csv", 1, "Periodo", "1", "2", :key)]
        end
    end
end
