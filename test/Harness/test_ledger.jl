using Test

ledger_table(cols, rows) = join([join(cols, ';'); [join(r, ';') for r in rows]], "\n") * "\n"

ledger_lines(kind = "value", extra = ["column = \"C\""]) = [
    "id = \"e1\"", "file = \"resultado_x.csv\"", "kind = \"$kind\"",
    "adr = \"ADR-001\"", "ticket = \"ticket-000\"", "justification = \"j\"", extra...,
]

ledger_body(lines) = "[[divergence]]\n" * join(lines, "\n") * "\n"

ledger_entry(id, kind, extra...; file = "resultado_x.csv") = ledger_body([
    "id = \"$id\"", "file = \"$file\"", "kind = \"$kind\"",
    "adr = \"ADR-001\"", "ticket = \"ticket-000\"", "justification = \"j\"", extra...,
])

function ledger_dirs(f, files_oracle::Dict, files_expected::Dict)
    mktempdir() do dir
        odir, jdir = joinpath(dir, "oracle"), joinpath(dir, "expected")
        mkpath(odir)
        mkpath(jdir)
        for (name, text) in files_oracle
            write(joinpath(odir, name), text)
        end
        for (name, text) in files_expected
            write(joinpath(jdir, name), text)
        end
        f(odir, jdir, dir)
    end
end

function ledger_check(body, cols, orows, jrows; kwargs...)
    ledger_dirs(Dict("resultado_x.csv" => ledger_table(cols, orows)),
                Dict("resultado_x.csv" => ledger_table(cols, jrows))) do odir, jdir, dir
        path = joinpath(dir, "DIVERGENCES.toml")
        write(path, "schema_version = 1\n" * body)
        cross_check(odir, jdir, load_ledger(path); kwargs...)
    end
end

function ledger_error(body; top = "schema_version = 1\n")
    mktempdir() do dir
        path = joinpath(dir, "DIVERGENCES.toml")
        write(path, top * body)
        try
            load_ledger(path)
            nothing
        catch e
            e
        end
    end
end

ledger_clean(r) = isempty(r.uncovered) && isempty(r.stale)

@testset "Divergence ledger" begin
    flow_cols = ["Linha", "FluxoMW"]
    flow_oracle = [["L1", "10.0"], ["L2", "20.0"]]
    flow_expected = [["L1", "10.0"], ["L2", "25.0"]]
    flow_entry = ledger_entry("flow", "value", "column = \"FluxoMW\"", "match = { Linha = \"L2\" }")

    @testset "Divergence" begin
        @test fieldtypes(Divergence) == (String, String, Symbol, Union{String,Nothing}, Dict{String,String},
                                         String, String, String, Union{String,Nothing}, Union{Int,Nothing})
    end

    @testset "value" begin
        @test ledger_clean(ledger_check(flow_entry, flow_cols, flow_oracle, flow_expected))

        r = ledger_check("", flow_cols, flow_oracle, flow_expected)
        @test r.uncovered == [Mismatch("resultado_x.csv", 2, "FluxoMW", "20.0", "25.0", :numeric)]
        @test isempty(r.stale)

        r = ledger_check(flow_entry, flow_cols, flow_oracle, flow_oracle)
        @test isempty(r.uncovered)
        @test [d.id for d in r.stale] == ["flow"]

        @testset "match selects rows and column selects the cell" begin
            for other in ("column = \"FluxoMW\"\nmatch = { Linha = \"L1\" }",
                          "column = \"Linha\"\nmatch = { Linha = \"L2\" }",
                          "column = \"FluxoMW\"\nmatch = { Linha = \"L2\", Nope = \"x\" }")
                r = ledger_check(ledger_entry("o", "value", other), flow_cols, flow_oracle, flow_expected)
                @test length(r.uncovered) == 1
                @test [d.id for d in r.stale] == ["o"]
            end
        end

        @testset "empty or absent match covers every row of the file" begin
            expected = [["L1", "11.0"], ["L2", "25.0"]]
            for match in ("", "match = {}")
                r = ledger_check(ledger_entry("all", "value", "column = \"FluxoMW\"", match),
                                 flow_cols, flow_oracle, expected)
                @test ledger_clean(r)
            end
        end

        @testset "match is exact text on the oracle row" begin
            oracle = [[" L2  ", "20.0"]]
            expected = [[" L2  ", "25.0"]]
            @test ledger_clean(ledger_check(
                ledger_entry("padded", "value", "column = \"FluxoMW\"", "match = { Linha = \" L2  \" }"),
                flow_cols, oracle, expected))
            r = ledger_check(ledger_entry("trimmed", "value", "column = \"FluxoMW\"", "match = { Linha = \"L2\" }"),
                             flow_cols, oracle, expected)
            @test length(r.uncovered) == 1 && length(r.stale) == 1

            r = ledger_check(ledger_entry("o", "value", "column = \"FluxoMW\"", "match = { Linha = \"L3\" }"),
                             flow_cols, [["L3", "1.0"], ["L2", "2.0"]], [["L2", "3.0"], ["L3", "4.0"]])
            @test [(m.row, m.column) for m in r.uncovered] == [(1, "Linha"), (2, "Linha"), (2, "FluxoMW")]
            @test isempty(r.stale)
        end

        @testset "text difference in the column" begin
            r = ledger_check(ledger_entry("status", "value", "column = \"Status\""),
                             ["Linha", "Status"], [["L1", "OPTIMAL"]], [["L1", "INFEASIBLE"]])
            @test ledger_clean(r)
        end

        @testset "does not widen numeric tolerance" begin
            r = ledger_check(flow_entry, flow_cols, flow_oracle, [["L1", "10.0"], ["L2", "20.0"]])
            @test isempty(r.uncovered)
            @test length(r.stale) == 1
            r = ledger_check(ledger_entry("o", "value", "column = \"FluxoMW\"", "match = { Linha = \"L2\" }"),
                             flow_cols, flow_oracle, [["L1", "10.5"], ["L2", "25.0"]])
            @test [m.row for m in r.uncovered] == [1]
        end
    end

    @testset "degenerate-tie" begin
        tie = ledger_entry("tie", "degenerate-tie", "column = \"FluxoMW\"", "match = { Linha = \"L2\" }",
                           "evidence = \"objective equal within rtol 1e-7\"")
        @test ledger_clean(ledger_check(tie, flow_cols, flow_oracle, flow_expected))
        r = ledger_check(tie, flow_cols, flow_oracle, flow_oracle)
        @test [d.id for d in r.stale] == ["tie"]

        @testset "entries are independent" begin
            r = ledger_check(flow_entry * tie, flow_cols, flow_oracle, flow_expected)
            @test ledger_clean(r)
        end
    end

    @testset "key-shift" begin
        cols = ["Periodo", "CMO"]
        oracle = [["0", "1.5"], ["1", "1.5"], ["2", "1.5"]]
        expected = [["1", "1.5"], ["2", "1.5"], ["3", "1.5"]]
        shift(offset; match = "") = ledger_entry("shift", "key-shift", "column = \"Periodo\"", "offset = $offset", match)

        @test ledger_clean(ledger_check(shift(1), cols, oracle, expected))

        r = ledger_check(shift(2), cols, oracle, expected)
        @test [m.row for m in r.uncovered] == [1, 2, 3]
        @test [d.id for d in r.stale] == ["shift"]

        r = ledger_check(shift(1; match = "match = { Periodo = \"0\" }"), cols, oracle, expected)
        @test [m.row for m in r.uncovered] == [2, 3]
        @test isempty(r.stale)

        r = ledger_check(shift(1; match = "match = { Periodo = \"1\" }"), cols, oracle, expected)
        @test [m.row for m in r.uncovered] == [1, 3]

        @test ledger_clean(ledger_check(shift(-1), cols, expected, oracle))

        r = ledger_check(shift(1), cols, [["A", "1.5"]], [["B", "1.5"]])
        @test length(r.uncovered) == 1 && length(r.stale) == 1

        r = ledger_check(shift(1), cols, [["1", "1.5"]], [["2", "2.5"]])
        @test [m.column for m in r.uncovered] == ["CMO"]
        @test isempty(r.stale)
    end

    @testset "row-added" begin
        cols = ["Nome", "Valor"]
        oracle = [["A", "1.0"], ["B", "2.0"]]
        expected = [["A", "1.0"], ["B", "2.0"], ["C", "3.0"]]
        added(match) = ledger_entry("added", "row-added", match)

        @test ledger_clean(ledger_check(added("match = { Nome = \"C\" }"), cols, oracle, expected))
        @test ledger_clean(ledger_check(added(""), cols, oracle, expected))

        r = ledger_check("", cols, oracle, expected)
        @test r.uncovered == [Mismatch("resultado_x.csv", 0, "", "2", "3", :row_count)]

        @testset "match must select a row only in expected" begin
            for match in ("match = { Nome = \"Z\" }", "match = { Nome = \"A\" }")
                r = ledger_check(added(match), cols, oracle, expected)
                @test length(r.uncovered) == 1
                @test [d.id for d in r.stale] == ["added"]
            end
        end

        @testset "no added row, no coverage" begin
            r = ledger_check(added("match = { Nome = \"C\" }"), cols, oracle, oracle)
            @test isempty(r.uncovered)
            @test length(r.stale) == 1
        end

        @testset "duplicate rows are counted" begin
            r = ledger_check(added("match = { Nome = \"A\" }"), cols, [["A", "1.0"]], [["A", "1.0"], ["A", "1.0"]])
            @test ledger_clean(r)
        end

        @testset "row-removed does not cover an added row" begin
            r = ledger_check(ledger_entry("removed", "row-removed", "match = { Nome = \"C\" }"), cols, oracle, expected)
            @test length(r.uncovered) == 1 && length(r.stale) == 1
        end
    end

    @testset "row-removed" begin
        cols = ["Nome", "Valor"]
        oracle = [["A", "1.0"], ["B", "2.0"], ["C", "3.0"]]
        expected = [["A", "1.0"], ["B", "2.0"]]
        removed(match) = ledger_entry("removed", "row-removed", match)

        @test ledger_clean(ledger_check(removed("match = { Nome = \"C\" }"), cols, oracle, expected))

        r = ledger_check(removed("match = { Nome = \"Z\" }"), cols, oracle, expected)
        @test length(r.uncovered) == 1 && [d.id for d in r.stale] == ["removed"]

        r = ledger_check(removed("match = { Nome = \"C\" }"), cols, oracle, oracle)
        @test isempty(r.uncovered) && length(r.stale) == 1

        r = ledger_check(ledger_entry("added", "row-added", "match = { Nome = \"C\" }"), cols, oracle, expected)
        @test length(r.uncovered) == 1 && length(r.stale) == 1
    end

    @testset "row-added and row-removed cover per-row mismatches" begin
        cols = ["Nome", "Valor"]
        oracle = [["A", "1.0"], ["B", "2.0"]]
        expected = [["A", "1.0"], ["C", "3.0"]]
        added(name) = ledger_entry("added", "row-added", "match = { Nome = \"$name\" }")
        removed(name) = ledger_entry("removed", "row-removed", "match = { Nome = \"$name\" }")

        r = ledger_check("", cols, oracle, expected)
        @test [(m.row, m.column) for m in r.uncovered] == [(2, "Nome"), (2, "Valor")]

        @test ledger_clean(ledger_check(added("C"), cols, oracle, expected))
        @test ledger_clean(ledger_check(removed("B"), cols, oracle, expected))
        @test ledger_clean(ledger_check(added("C") * removed("B"), cols, oracle, expected))

        r = ledger_check(added("B"), cols, oracle, expected)
        @test length(r.uncovered) == 2 && length(r.stale) == 1
        r = ledger_check(removed("C"), cols, oracle, expected)
        @test length(r.uncovered) == 2 && length(r.stale) == 1
    end

    @testset "file-level differences are never covered" begin
        entries = join([ledger_entry("e-$k", k, "column = \"Nome\"", "offset = 1", "evidence = \"e\"")
                        for k in ("value", "row-added", "row-removed", "key-shift", "degenerate-tie")])
        table = ledger_table(["Nome"], [["A"]])
        for (label, files_o, files_e, kind) in [
            ("missing", Dict("resultado_x.csv" => table), Dict{String,String}(), :missing_file),
            ("extra", Dict{String,String}(), Dict("resultado_x.csv" => table), :extra_file),
            ("header", Dict("resultado_x.csv" => table), Dict("resultado_x.csv" => ledger_table(["Outro"], [["A"]])), :header),
        ]
            r = ledger_dirs(files_o, files_e) do odir, jdir, dir
                path = joinpath(dir, "DIVERGENCES.toml")
                write(path, "schema_version = 1\n" * entries)
                cross_check(odir, jdir, load_ledger(path))
            end
            @test [m.kind for m in r.uncovered] == [kind]
            @test length(r.stale) == 5
        end
    end

    @testset "entries cover their own file only" begin
        other = ledger_entry("flow", "value", "column = \"FluxoMW\"", "match = { Linha = \"L2\" }"; file = "resultado_y.csv")
        r = ledger_check(other, flow_cols, flow_oracle, flow_expected)
        @test length(r.uncovered) == 1
        @test [d.id for d in r.stale] == ["flow"]
    end

    @testset "excluded_files" begin
        r = ledger_check("", flow_cols, flow_oracle, flow_expected; excluded_files = ["resultado_x.csv"])
        @test ledger_clean(r)
    end

    @testset "results are ordered" begin
        entries = ledger_entry("b", "value", "column = \"FluxoMW\"", "match = { Linha = \"none\" }") *
                  ledger_entry("a", "value", "column = \"FluxoMW\"", "match = { Linha = \"none\" }")
        oracle = [["L1", "1.0"], ["L2", "2.0"], ["L3", "3.0"]]
        expected = [["L1", "9.0"], ["L2", "9.0"], ["L3", "9.0"]]
        r = ledger_check(entries, flow_cols, oracle, expected)
        @test [m.row for m in r.uncovered] == [1, 2, 3]
        @test [d.id for d in r.stale] == ["b", "a"]
    end

    @testset "load_ledger" begin
        @testset "valid ledger" begin
            body = ledger_entry("v", "value", "column = \"C\"", "match = { K = \"1\" }") *
                   ledger_entry("s", "key-shift", "column = \"P\"", "offset = -1") *
                   ledger_entry("t", "degenerate-tie", "column = \"C\"", "evidence = \"proof\"") *
                   ledger_entry("r", "row-added")
            ledger = mktempdir() do dir
                path = joinpath(dir, "DIVERGENCES.toml")
                write(path, "schema_version = 1\n" * body)
                load_ledger(path)
            end
            @test [d.id for d in ledger] == ["v", "s", "t", "r"]
            @test [d.kind for d in ledger] == [:value, Symbol("key-shift"), Symbol("degenerate-tie"), Symbol("row-added")]
            @test ledger[1].match == Dict("K" => "1")
            @test ledger[1].column == "C" && ledger[1].offset === nothing && ledger[1].evidence === nothing
            @test ledger[2].offset === -1 && isempty(ledger[2].match)
            @test ledger[3].evidence == "proof"
            @test ledger[4].column === nothing
            @test (ledger[1].file, ledger[1].adr, ledger[1].ticket, ledger[1].justification) ==
                  ("resultado_x.csv", "ADR-001", "ticket-000", "j")
        end

        @testset "schema_version only" begin
            @test mktempdir() do dir
                path = joinpath(dir, "DIVERGENCES.toml")
                write(path, "schema_version = 1\n")
                load_ledger(path)
            end == Divergence[]
        end

        @testset "schema_version" begin
            for (top, found) in [("", "schema_version"), ("schema_version = 2\n", "2"),
                                 ("schema_version = \"1\"\n", "\"1\""), ("schema_version = 1.0\n", "1.0")]
                e = ledger_error(""; top)
                @test e isa ArgumentError
                @test occursin("DIVERGENCES.toml", e.msg) && occursin(found, e.msg)
            end
        end

        @testset "unknown top-level field and malformed divergence" begin
            e = ledger_error("extra = 1\n")
            @test e isa ArgumentError && occursin("extra", e.msg)
            e = ledger_error("divergence = 3\n")
            @test e isa ArgumentError && occursin("divergence", e.msg)
            e = ledger_error("[divergence]\nid = \"x\"\n")
            @test e isa ArgumentError && occursin("divergence", e.msg)
        end

        @testset "missing required field $f" for f in ("file", "kind", "adr", "ticket", "justification")
            e = ledger_error(ledger_body(filter(l -> !startswith(l, "$f ="), ledger_lines())))
            @test e isa ArgumentError
            @test occursin("DIVERGENCES.toml", e.msg) && occursin("'e1'", e.msg) && occursin("'$f'", e.msg)
        end

        @testset "missing id names the position" begin
            e = ledger_error(ledger_entry("x", "row-added") *
                             ledger_body(filter(l -> !startswith(l, "id ="), ledger_lines())))
            @test e isa ArgumentError
            @test occursin("DIVERGENCES.toml", e.msg) && occursin("#2", e.msg) && occursin("'id'", e.msg)
        end

        @testset "per-kind required field" begin
            complete = ["value" => ["column = \"C\""],
                        "key-shift" => ["column = \"C\"", "offset = 1"],
                        "degenerate-tie" => ["column = \"C\"", "evidence = \"e\""]]
            for (kind, fields) in complete, dropped in fields
                name = first(split(dropped, " ="))
                e = ledger_error(ledger_body(ledger_lines(kind, filter(!=(dropped), fields))))
                @test e isa ArgumentError
                @test occursin("DIVERGENCES.toml", e.msg) && occursin("'e1'", e.msg) && occursin("'$name'", e.msg)
            end
            for kind in ("row-added", "row-removed")
                @test ledger_error(ledger_body(ledger_lines(kind, String[]))) === nothing
            end
        end

        @testset "unknown kind" begin
            e = ledger_error(ledger_body(ledger_lines("values")))
            @test e isa ArgumentError
            @test occursin("'e1'", e.msg) && occursin("'values'", e.msg)
            @test occursin("value, row-added, row-removed, key-shift, degenerate-tie", e.msg)
        end

        @testset "malformed adr $adr" for adr in ("ADR-27", "adr-027", "ADR-0271", "ADR-027\\n", "ADR-02a", "")
            e = ledger_error(ledger_body(replace.(ledger_lines(), "ADR-001" => adr)))
            @test e isa ArgumentError
            @test occursin("'e1'", e.msg) && occursin("'adr'", e.msg)
        end

        @testset "non-integer offset $offset" for offset in ("1.5", "\"1\"", "true")
            e = ledger_error(ledger_body(ledger_lines("key-shift", ["column = \"C\"", "offset = $offset"])))
            @test e isa ArgumentError
            @test occursin("'e1'", e.msg) && occursin("'offset'", e.msg) && occursin(offset, e.msg)
        end

        @testset "duplicate id" begin
            e = ledger_error(ledger_entry("same", "row-added") * ledger_entry("other", "row-added") *
                             ledger_entry("same", "row-removed"))
            @test e isa ArgumentError
            @test occursin("'same'", e.msg) && occursin("'id'", e.msg)
        end

        @testset "unknown field" begin
            e = ledger_error(ledger_body(ledger_lines("value", ["column = \"C\"", "colunm = \"C\""])))
            @test e isa ArgumentError
            @test occursin("'e1'", e.msg) && occursin("'colunm'", e.msg)
        end

        @testset "ill-typed field" begin
            e = ledger_error(ledger_body(replace.(ledger_lines(), "file = \"resultado_x.csv\"" => "file = 3")))
            @test e isa ArgumentError
            @test occursin("'e1'", e.msg) && occursin("'file'", e.msg) && occursin("3", e.msg)
        end

        @testset "match must be a table of strings" begin
            for match in ("match = { Periodo = 1 }", "match = { Periodo = [\"1\"] }", "match = \"Periodo\"")
                e = ledger_error(ledger_body(ledger_lines("value", ["column = \"C\"", match])))
                @test e isa ArgumentError
                @test occursin("'e1'", e.msg) && occursin("'match'", e.msg)
            end
        end
    end

    @testset "vendored 24Barras" begin
        case = joinpath(FIXTURES_DIR, "24Barras")
        r = cross_check(joinpath(case, "oracle", "RESULTADOS"), joinpath(case, "expected"),
                        load_ledger(joinpath(case, "DIVERGENCES.toml")))
        @test isempty(r.uncovered)
        @test isempty(r.stale)
    end
end
