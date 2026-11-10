"""
One difference between an oracle result file and a Julia result file.

`kind` is one of `:missing_file`, `:extra_file`, `:header`, `:row_count`, `:key`, `:numeric`.
`row` is the 1-based data row (the first line after the column line is row 1); file-level
kinds use `row = 0` and `column = ""`. `:header` carries the two column lines, `:row_count`
the two row counts, `:missing_file`/`:extra_file` the texts `present`/`absent`.
"""
struct Mismatch
    file::String
    row::Int
    column::String
    oracle::String
    julia::String
    kind::Symbol
end

const DEFAULT_EXCLUDED = Set(["TempoResolucaoSeg", "NumeroRestricoes", "NumeroVariaveis"])

const GOLDEN_RTOL = 1e-7
const GOLDEN_HEADER_PREFIX = "ONS - Operador"

"""
    read_result_table(path) -> (columns, rows)

Read a `;`-separated result file, dropping the ONS header block when the first line starts
with `ONS - Operador`. Cells are exact text. Throws `ErrorException` naming `path` when no
column line follows.
"""
function read_result_table(path::AbstractString)::Tuple{Vector{String},Vector{Vector{String}}}
    lines = [endswith(l, '\r') ? String(chop(l)) : l for l in eachline(path)]
    start = 1
    if !isempty(lines) && startswith(lines[1], GOLDEN_HEADER_PREFIX)
        blanks = findall(isempty, lines)
        start = length(blanks) >= 2 ? blanks[2] + 1 : length(lines) + 1
    end
    start <= length(lines) || error("$path: no column line")
    cells(l) = String.(split(l, ';'))
    return cells(lines[start]), [cells(l) for l in lines[start+1:end]]
end

function decimal_atol(oracle::AbstractString)::Float64
    t = strip(oracle)
    occursin(r"[eE]", t) && return 0.0
    return 1.5 * 10.0^(-(length(t) - findlast('.', t)))
end

function cell_mismatch(col::AbstractString, o::AbstractString, j::AbstractString)::Union{Nothing,Symbol}
    if occursin('.', o)
        ov, jv = tryparse(Float64, o), tryparse(Float64, j)
        if ov !== nothing && jv !== nothing
            atol = col == "ValorFuncaoObjetivo" ? 0.0 : decimal_atol(o)
            return abs(jv - ov) <= atol + GOLDEN_RTOL * abs(ov) ? nothing : :numeric
        end
    end
    return o == j ? nothing : :key
end

"""
    compare_result_file(oracle_path, julia_path; excluded_columns = DEFAULT_EXCLUDED) -> Vector{Mismatch}

Compare two result files under the ADR-038 tiers. Mismatches are ordered by row, then column.
A column-line difference or a row-count difference is reported alone, as one file-level mismatch.
"""
function compare_result_file(oracle_path::AbstractString, julia_path::AbstractString;
                             excluded_columns = DEFAULT_EXCLUDED)::Vector{Mismatch}
    file = basename(oracle_path)
    ocols, orows = read_result_table(oracle_path)
    jcols, jrows = read_result_table(julia_path)
    ocols == jcols ||
        return [Mismatch(file, 0, "", join(ocols, ';'), join(jcols, ';'), :header)]
    length(orows) == length(jrows) ||
        return [Mismatch(file, 0, "", string(length(orows)), string(length(jrows)), :row_count)]
    out = Mismatch[]
    for r in eachindex(orows)
        orow, jrow = orows[r], jrows[r]
        if length(orow) != length(jrow)
            push!(out, Mismatch(file, r, "", join(orow, ';'), join(jrow, ';'), :key))
            continue
        end
        for c in eachindex(orow)
            col = get(ocols, c, "")
            col in excluded_columns && continue
            kind = cell_mismatch(col, orow[c], jrow[c])
            kind === nothing || push!(out, Mismatch(file, r, col, orow[c], jrow[c], kind))
        end
    end
    return out
end

"""
    compare_result_dirs(oracle_dir, julia_dir; excluded_files = String[]) -> Vector{Mismatch}

Compare two flat result directories: file sets first (`:missing_file`, `:extra_file`), then
every common file with [`compare_result_file`](@ref). Mismatches are ordered by file name.
"""
function compare_result_dirs(oracle_dir::AbstractString, julia_dir::AbstractString;
                             excluded_files = String[])::Vector{Mismatch}
    onames, jnames = Set(readdir(oracle_dir)), Set(readdir(julia_dir))
    out = Mismatch[]
    for name in sort!(collect(union(onames, jnames)))
        name in excluded_files && continue
        if name ∉ jnames
            push!(out, Mismatch(name, 0, "", "present", "absent", :missing_file))
        elseif name ∉ onames
            push!(out, Mismatch(name, 0, "", "absent", "present", :extra_file))
        else
            append!(out, compare_result_file(joinpath(oracle_dir, name), joinpath(julia_dir, name)))
        end
    end
    return out
end
