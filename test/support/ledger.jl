import TOML

"""
One entry of a fixture's `DIVERGENCES.toml` (schema version 1, `test/fixtures/README.md`).

`kind` holds the README spelling as a `Symbol`: `:value`, `Symbol("row-added")`,
`Symbol("row-removed")`, `Symbol("key-shift")` or `Symbol("degenerate-tie")`.
"""
struct Divergence
    id::String
    file::String
    kind::Symbol
    column::Union{String,Nothing}
    match::Dict{String,String}
    adr::String
    ticket::String
    justification::String
    evidence::Union{String,Nothing}
    offset::Union{Int,Nothing}
end

const LEDGER_KINDS = Symbol.(["value", "row-added", "row-removed", "key-shift", "degenerate-tie"])
const LEDGER_FIELDS = ["id", "file", "kind", "column", "match", "adr", "ticket", "justification", "evidence", "offset"]
const ResultTable = Tuple{Vector{String},Vector{Vector{String}}}

function ledger_field(e, key::String, ::Type{T}, required::Bool, bad) where {T}
    if !haskey(e, key)
        required && bad("missing required field '$key'")
        return nothing
    end
    v = e[key]
    v isa T || bad("field '$key' must be $(T === String ? "a string" : "an integer"), found $(repr(v))")
    return v
end

"""
    load_ledger(path) -> Vector{Divergence}

Read and validate a `DIVERGENCES.toml` against the README schema. Every violation (wrong or
missing `schema_version`, unknown field or kind, missing or ill-typed field, malformed `adr`,
duplicate `id`) throws `ArgumentError` naming `path` and the entry `id` (`#<position>` when the
`id` is missing).
"""
function load_ledger(path::AbstractString)::Vector{Divergence}
    raw = TOML.parsefile(path)
    haskey(raw, "schema_version") ||
        throw(ArgumentError("$path: missing required field 'schema_version'; expected 1"))
    raw["schema_version"] === 1 ||
        throw(ArgumentError("$path: schema_version is $(repr(raw["schema_version"])); expected 1"))
    for k in sort!(collect(keys(raw)))
        k in ("schema_version", "divergence") || throw(ArgumentError("$path: unknown top-level field '$k'"))
    end
    entries = get(raw, "divergence", Any[])
    entries isa Vector && all(e -> e isa AbstractDict, entries) ||
        throw(ArgumentError("$path: 'divergence' must be an array of tables"))

    out = Divergence[]
    seen = Set{String}()
    for (i, e) in enumerate(entries)
        id = get(e, "id", nothing)
        bad(msg) = throw(ArgumentError("$path: entry $(id isa String ? "'$id'" : "#$i"): $msg"))
        id isa String || bad(id === nothing ? "missing required field 'id'" : "field 'id' must be a string, found $(repr(id))")
        for k in sort!(collect(keys(e)))
            k in LEDGER_FIELDS || bad("unknown field '$k' with value $(repr(e[k]))")
        end
        id in seen && bad("field 'id' duplicates an earlier entry: $(repr(id))")
        push!(seen, id)

        file = ledger_field(e, "file", String, true, bad)
        kind_text = ledger_field(e, "kind", String, true, bad)
        Symbol(kind_text) in LEDGER_KINDS ||
            bad("unknown kind '$kind_text'; allowed: $(join(LEDGER_KINDS, ", "))")
        adr = ledger_field(e, "adr", String, true, bad)
        occursin(r"^ADR-[0-9]{3}\z", adr) ||
            bad("field 'adr' must be 'ADR-' plus three digits, found $(repr(adr))")
        ticket = ledger_field(e, "ticket", String, true, bad)
        justification = ledger_field(e, "justification", String, true, bad)
        column = ledger_field(e, "column", String, kind_text in ("value", "key-shift", "degenerate-tie"), bad)
        evidence = ledger_field(e, "evidence", String, kind_text == "degenerate-tie", bad)
        offset = ledger_field(e, "offset", Int, kind_text == "key-shift", bad)
        raw_match = get(e, "match", Dict{String,Any}())
        raw_match isa AbstractDict && all(v -> v isa String, values(raw_match)) ||
            bad("field 'match' must be a table of strings, found $(repr(raw_match))")

        push!(out, Divergence(id, file, Symbol(kind_text), column, Dict{String,String}(raw_match),
                              adr, ticket, justification, evidence, offset))
    end
    return out
end

function ledger_row_matches(d::Divergence, columns::Vector{String}, row::Vector{String})::Bool
    for (k, v) in d.match
        j = findfirst(==(k), columns)
        (j !== nothing && j <= length(row) && row[j] == v) || return false
    end
    return true
end

# Flags the rows of `a` whose exact text has no unused counterpart among the rows of `b`.
function ledger_one_sided(a::Vector{Vector{String}}, b::Vector{Vector{String}})::BitVector
    left = Dict{Vector{String},Int}()
    for r in b
        left[r] = get(left, r, 0) + 1
    end
    flags = falses(length(a))
    for (i, r) in pairs(a)
        n = get(left, r, 0)
        n > 0 ? (left[r] = n - 1) : (flags[i] = true)
    end
    return flags
end

"""
    covers(d, m, oracle_table, julia_table) -> Bool

Whether ledger entry `d` covers mismatch `m`, as defined by the README (Cross-check). `m` comes
from `compare_result_dirs(oracle_dir, expected_dir)`, so `m.julia` is the `expected/` value.
`oracle_table` and `julia_table` are the `read_result_table` results of `m.file` on each side.

`match` is evaluated on the oracle row, except for `row-added`, which uses the `expected/` row.
A row is present on only one side when its exact text has no counterpart on the other side
(duplicates counted). `row-added` and `row-removed` cover the `:row_count` mismatch only when
such a row matches `d.match`. A missing file, an extra file and a column-line difference are
never covered.
"""
function covers(d::Divergence, m::Mismatch, oracle_table::ResultTable, julia_table::ResultTable)::Bool
    m.file == d.file || return false
    ocols, orows = oracle_table
    jcols, jrows = julia_table
    kind = String(d.kind)
    if kind in ("row-added", "row-removed")
        cols, rows, only_here = kind == "row-added" ? (jcols, jrows, ledger_one_sided(jrows, orows)) :
                                                      (ocols, orows, ledger_one_sided(orows, jrows))
        hit(i) = only_here[i] && ledger_row_matches(d, cols, rows[i])
        m.kind === :row_count && return any(hit, eachindex(rows))
        return m.kind in (:numeric, :key) && 1 <= m.row <= length(rows) && hit(m.row)
    end
    m.kind in (:numeric, :key) && m.column == d.column && 1 <= m.row <= length(orows) &&
        ledger_row_matches(d, ocols, orows[m.row]) || return false
    if kind == "key-shift"
        m.kind === :key || return false
        o, j = tryparse(Int, m.oracle), tryparse(Int, m.julia)
        return o !== nothing && j !== nothing && j == o + d.offset
    end
    return true
end

"""
    cross_check(oracle_dir, expected_dir, ledger; excluded_files = String[]) -> (uncovered, stale)

The ledger pass of the README (Cross-check): compare `expected_dir` against `oracle_dir` with
[`compare_result_dirs`](@ref) (reference side the oracle) and check the differences against `ledger`.
`uncovered` holds the mismatches no entry covers, in comparator order; `stale` holds the entries
that cover no mismatch, in ledger order. Entries are evaluated independently.
"""
function cross_check(oracle_dir::AbstractString, expected_dir::AbstractString, ledger::Vector{Divergence};
                     excluded_files = String[])::@NamedTuple{uncovered::Vector{Mismatch}, stale::Vector{Divergence}}
    tables = Dict{String,Tuple{ResultTable,ResultTable}}()
    tables_of(file) = get!(tables, file) do
        (read_result_table(joinpath(oracle_dir, file)), read_result_table(joinpath(expected_dir, file)))
    end
    used = falses(length(ledger))
    uncovered = Mismatch[]
    for m in compare_result_dirs(oracle_dir, expected_dir; excluded_files)
        covered = false
        if m.kind in (:numeric, :key, :row_count)
            for (i, d) in enumerate(ledger)
                d.file == m.file || continue
                ot, jt = tables_of(m.file)
                if covers(d, m, ot, jt)
                    used[i] = covered = true
                end
            end
        end
        covered || push!(uncovered, m)
    end
    return (uncovered = uncovered, stale = ledger[.!used])
end
