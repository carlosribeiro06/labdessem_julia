#!/usr/bin/env julia
# Regenerates the oracle goldens of test/fixtures/ from labdessem_rust pinned at PIN.
# The contract (layout, fixture.toml schema, assertion kinds, cli.log normalization,
# generate/verify/overwrite modes, exit codes, failure messages) is test/fixtures/README.md.
#
#   julia --startup-file=no tools/regen_oracle_goldens.jl [--oracle PATH] [--fixtures DIR] [--only NAME]... [--overwrite]

using TOML
using SHA

const PIN = "61c20f1"
const BASE = "24Barras"
const REPO_ROOT = dirname(@__DIR__)
const USAGE = "usage: julia --startup-file=no tools/regen_oracle_goldens.jl [--oracle PATH] [--fixtures DIR] [--only NAME]... [--overwrite]"
const ASSERT_KINDS = [
    "exit_code",
    "stage_sequence",
    "files_exact",
    "column_nonzero",
    "objective_differs_from_base",
    "row_match",
]
const CLI_LOG_TIME_MASKS = [
    r"solve time = \d+\.\d+ s" => "solve time = <t> s",
    r"time = \d+\.\d+s" => "time = <t>s",
]

struct Failure <: Exception
    code::Int
    msg::String
end

struct CheckFailed <: Exception
    msg::String
end

struct Options
    oracle::String
    fixtures::String
    only::Vector{String}
    overwrite::Bool
    cmdline::String
end

struct Fixture
    name::String
    dir::String
    base::Bool
    asserts::Vector{Dict{String,Any}}
end

struct Table
    cols::Vector{String}
    rows::Vector{Vector{String}}
end

fail(code::Int, msg::AbstractString) = throw(Failure(code, msg))
eprintln(msg) = println(stderr, msg)
check(ok::Bool, msg) = ok || throw(CheckFailed(string(msg)))

# ---------------------------------------------------------------- command line

function parse_args(args)
    oracle = joinpath(REPO_ROOT, "..", "labdessem_rust")
    fixtures = joinpath(REPO_ROOT, "test", "fixtures")
    only = String[]
    overwrite = false
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--overwrite"
            overwrite = true
        elseif a in ("--oracle", "--fixtures", "--only")
            i < length(args) || fail(1, "$a requires a value\n$USAGE")
            v = args[i+=1]
            a == "--oracle" ? (oracle = v) : a == "--fixtures" ? (fixtures = v) : push!(only, v)
        else
            fail(1, "unknown argument '$a'\n$USAGE")
        end
        i += 1
    end
    cmdline = join(
        filter(
            !isempty,
            [
                "julia --startup-file=no",
                relpath(abspath(PROGRAM_FILE), REPO_ROOT),
                Base.shell_escape(args...),
            ],
        ),
        " ",
    )
    Options(abspath(oracle), abspath(fixtures), only, overwrite, cmdline)
end

# ------------------------------------------------------------------- processes

function capture(cmd::Cmd; input = devnull, code::Int = 1)
    out, err = IOBuffer(), IOBuffer()
    p = run(pipeline(ignorestatus(cmd); stdin = input, stdout = out, stderr = err))
    success(p) || fail(code, "command failed: $cmd\n$(String(take!(err)))")
    take!(out)
end

text(cmd::Cmd; kw...) = String(capture(cmd; kw...))

function preflight(oracle)
    pre(msg) = fail(2, "preflight: $msg (the oracle must be a clean checkout at $PIN)")
    isdir(oracle) || pre("$oracle is not a directory")
    sha = try
        strip(text(`git -C $oracle rev-parse HEAD`))
    catch e
        e isa Failure || rethrow()
        pre(e.msg)
    end
    startswith(sha, PIN) || pre("HEAD of $oracle is $sha")
    # --no-optional-locks: a plain `git status` may refresh the oracle's index, and the oracle is read-only.
    dirty = try
        text(`git --no-optional-locks -C $oracle status --porcelain`)
    catch e
        e isa Failure || rethrow()
        pre(e.msg)
    end
    isempty(dirty) || pre("worktree of $oracle is not clean:\n$dirty")
    String(sha)
end

function build_oracle(oracle, target)
    run_in_oracle(cmd) = Cmd(cmd; dir = oracle)
    capture(
        run_in_oracle(
            `cargo build --release --locked -p labdessem-cli --manifest-path $(joinpath(oracle, "Cargo.toml")) --target-dir $target`,
        ),
    )
    lock = TOML.parsefile(joinpath(oracle, "Cargo.lock"))
    highs = sort!([p["version"] for p in lock["package"] if p["name"] == "highs-sys"])
    (;
        bin = joinpath(target, "release", "labdessem"),
        rustc = strip(text(run_in_oracle(`rustc --version`))),
        cargo = strip(text(run_in_oracle(`cargo --version`))),
        highs_sys = join(highs, ", "),
    )
end

# ------------------------------------------------------------- fixture.toml

is_int(v) = v isa Integer && !(v isa Bool)
is_num(v) = v isa Real && !(v isa Bool)
is_strs(v) = v isa AbstractVector && all(x -> x isa AbstractString, v)

const ASSERT_SCHEMA = Dict(
    "exit_code" => ["value" => is_int],
    "stage_sequence" => ["value" => is_strs],
    "files_exact" => ["value" => v -> is_strs(v) && issorted(v) && allunique(v)],
    "column_nonzero" => ["file" => v -> v isa AbstractString, "column" => v -> v isa AbstractString],
    "objective_differs_from_base" =>
        ["stage" => v -> v isa AbstractString, "min_abs_delta" => v -> is_num(v) && v >= 0],
    "row_match" => [
        "file" => v -> v isa AbstractString,
        "where" => v -> v isa AbstractDict && all(x -> x isa AbstractString, values(v)),
        "column" => v -> v isa AbstractString,
        "value" => is_num,
        "atol" => v -> is_num(v) && v >= 0,
        "quantifier" => v -> v in ("all", "any"),
    ],
)

function load_fixture(name::String, dir::String)
    path = joinpath(dir, "fixture.toml")
    bad(msg) = fail(1, "$path: $msg")
    t = try
        TOML.parsefile(path)
    catch e
        e isa TOML.ParserError || rethrow()
        bad(sprint(showerror, e))
    end
    is_base = name == BASE

    for k in sort!(collect(keys(t)))
        k in ("name", "base", "description", "assert") ||
            bad("unknown field '$k' (value $(repr(t[k])))")
    end
    for k in ("name", "description", "assert")
        haskey(t, k) || bad("missing required field '$k'")
    end
    t["name"] == name ||
        bad("invalid value $(repr(t["name"])) for field 'name': must equal the directory name '$name'")
    is_base ||
        occursin(r"^[a-z0-9]+(-[a-z0-9]+)*$", name) ||
        bad("invalid value $(repr(name)) for field 'name': a variant name must be kebab-case")
    if is_base
        haskey(t, "base") && bad("invalid field 'base' (value $(repr(t["base"]))): must be absent in $BASE")
    else
        haskey(t, "base") || bad("missing required field 'base'")
        t["base"] == BASE ||
            bad("invalid value $(repr(t["base"])) for field 'base': the only allowed value is \"$BASE\"")
    end
    t["description"] isa AbstractString ||
        bad("invalid value $(repr(t["description"])) for field 'description'")
    asserts = t["assert"]
    (asserts isa AbstractVector && all(a -> a isa AbstractDict, asserts)) ||
        bad("invalid value $(repr(asserts)) for field 'assert': expected an array of tables")

    for (i, a) in enumerate(asserts)
        haskey(a, "kind") || bad("[[assert]] #$i: missing required field 'kind'")
        kind = a["kind"]
        kind in ASSERT_KINDS ||
            bad("[[assert]] #$i: unknown kind '$kind'; allowed: $(join(ASSERT_KINDS, ", "))")
        schema = ASSERT_SCHEMA[kind]
        for k in sort!(collect(keys(a)))
            k == "kind" ||
                any(f -> first(f) == k, schema) ||
                bad("[[assert]] #$i ($kind): unknown field '$k' (value $(repr(a[k])))")
        end
        for (field, valid) in schema
            haskey(a, field) || bad("[[assert]] #$i ($kind): missing required field '$field'")
            valid(a[field]) ||
                bad("[[assert]] #$i ($kind): invalid value $(repr(a[field])) for field '$field'")
        end
        is_base &&
            kind == "objective_differs_from_base" &&
            bad("[[assert]] #$i ($kind): not valid in the base fixture $BASE")
    end
    for kind in ("exit_code", "stage_sequence", "files_exact")
        any(a -> a["kind"] == kind, asserts) || bad("missing required assertion kind '$kind'")
    end
    Fixture(name, dir, is_base, asserts)
end

function discover(opts)
    found = Pair{String,String}[]
    isfile(joinpath(opts.fixtures, BASE, "fixture.toml")) && push!(found, BASE => joinpath(opts.fixtures, BASE))
    variants = joinpath(opts.fixtures, "variants")
    if isdir(variants)
        for n in sort!(readdir(variants))
            isfile(joinpath(variants, n, "fixture.toml")) && push!(found, n => joinpath(variants, n))
        end
    end
    names = [p.first for p in found]
    unknown = setdiff(opts.only, names)
    isempty(unknown) ||
        fail(1, "unknown fixture name(s) $(join(unknown, ", ")); found under $(opts.fixtures): $(join(names, ", "))")
    selected = isempty(opts.only) ? found : filter(p -> p.first in opts.only, found)
    isempty(selected) && fail(1, "no fixture.toml found under $(opts.fixtures)")
    [load_fixture(n, d) for (n, d) in selected]
end

# ----------------------------------------------------------- oracle case + run

function materialize(oracle, fx::Fixture, dest)
    archive = capture(
        `git -C $oracle archive $PIN examples/$BASE/CAD examples/$BASE/OPER examples/$BASE/study_config.json`,
    )
    capture(`tar -x --strip-components=2 -C $dest`; input = IOBuffer(archive))
    overlay = joinpath(fx.dir, "overlay")
    isdir(overlay) || return
    for (root, _, files) in walkdir(overlay), f in files
        src = joinpath(root, f)
        dst = joinpath(dest, relpath(src, overlay))
        mkpath(dirname(dst))
        cp(src, dst; force = true)
    end
end

function normalize_cli_log(text::AbstractString, case_dir::AbstractString)
    dirs = sort!(unique([case_dir, realpath(case_dir)]); by = length, rev = true)
    for d in dirs
        text = replace(text, d => "<CASE_DIR>")
    end
    for mask in CLI_LOG_TIME_MASKS
        text = replace(text, mask)
    end
    text
end

# One open file handle is both stdout and stderr, so line order is the oracle's own write order.
function run_oracle(bin, case, logpath)
    cmd = Cmd(`$bin run $case`; dir = case)
    p = open(logpath, "w") do io
        run(pipeline(ignorestatus(cmd); stdout = io, stderr = io))
    end
    # a signal-killed child reports exitcode 0
    p.termsignal == 0 || fail(1, "command killed by signal $(p.termsignal): $cmd")
    (; exit_code = p.exitcode, command = cmd, log = normalize_cli_log(read(logpath, String), case))
end

function snapshot(dir, prefix)
    files = Dict{String,Vector{UInt8}}()
    isdir(dir) || return files
    for (root, _, names) in walkdir(dir), n in names
        path = joinpath(root, n)
        files[joinpath(prefix, relpath(path, dir))] = read(path)
    end
    files
end

# ------------------------------------------------------------------ result files

split_lines(s) = (l = split(s, '\n'); !isempty(l) && isempty(l[end]) && pop!(l); l)

function column_line_index(lines)
    startswith(first(lines), "ONS - Operador") || return 1
    blanks = 0
    for (i, l) in enumerate(lines)
        if isempty(chopsuffix(l, "\r"))
            blanks += 1
            blanks == 2 && return i + 1
        end
    end
    error("result file header block has no terminating blank line")
end

function parse_table(s)
    lines = split_lines(s)
    k = column_line_index(lines)
    cells(l) = String.(split(chopsuffix(l, "\r"), ';'))
    Table(cells(lines[k]), [cells(l) for l in lines[k+1:end]])
end

function table(resdir, file)
    path = joinpath(resdir, file)
    check(isfile(path), "$path does not exist")
    parse_table(read(path, String))
end

function col(t::Table, name)
    j = findfirst(==(name), t.cols)
    check(j !== nothing, "column '$name' not found in $(t.cols)")
    j
end

cell(row, j) = get(row, j, "")

# ------------------------------------------------------------------- assertions

log_tail(log) = join(last(split_lines(log), 15), "\n")

function check_exit_code(a, ctx)
    check(
        ctx.exit_code == a["value"],
        "expected exit code $(a["value"]), observed $(ctx.exit_code); command $(ctx.command); log tail:\n$(log_tail(ctx.log))",
    )
end

function check_stage_sequence(a, ctx)
    t = table(ctx.resdir, "resultado_processo_iter.csv")
    e, i, s = col(t, "Etapa"), col(t, "Iteracao"), col(t, "StatusSolucao")
    seq = ["$(cell(r, e))#$(cell(r, i)) $(cell(r, s))" for r in t.rows]
    check(seq == a["value"], "expected $(a["value"]), observed $seq")
end

function check_files_exact(a, ctx)
    found = isdir(ctx.resdir) ? sort!(readdir(ctx.resdir)) : String[]
    check(
        found == a["value"],
        "missing $(setdiff(a["value"], found)), extra $(setdiff(found, a["value"])); observed $found",
    )
end

function check_column_nonzero(a, ctx)
    t = table(ctx.resdir, a["file"])
    j = col(t, a["column"])
    vals = filter(!isnothing, [tryparse(Float64, cell(r, j)) for r in t.rows])
    check(any(!iszero, vals), "no non-zero numeric cell in column '$(a["column"])' of $(a["file"]) ($(length(t.rows)) rows)")
end

function stage_objective(resdir, stage)
    t = table(resdir, "resultado_processo_iter.csv")
    e, o = col(t, "Etapa"), col(t, "ValorFuncaoObjetivo")
    hits = [r for r in t.rows if cell(r, e) == stage]
    check(length(hits) == 1, "stage '$stage' occurs in $(length(hits)) rows of $resdir/resultado_processo_iter.csv, exactly 1 required")
    v = tryparse(Float64, cell(only(hits), o))
    check(v !== nothing, "ValorFuncaoObjetivo of stage '$stage' in $resdir is not a number")
    v
end

function check_objective_differs_from_base(a, ctx)
    check(
        isdir(ctx.base_resdir),
        "base fixture oracle not found at $(ctx.base_resdir); generate $BASE first",
    )
    obj = stage_objective(ctx.resdir, a["stage"])
    base = stage_objective(ctx.base_resdir, a["stage"])
    check(
        abs(obj - base) >= a["min_abs_delta"],
        "stage '$(a["stage"])': objective $obj, base objective $base, |delta| $(abs(obj - base)) < $(a["min_abs_delta"])",
    )
end

function check_row_match(a, ctx)
    t = table(ctx.resdir, a["file"])
    j = col(t, a["column"])
    conds = [col(t, k) => v for (k, v) in a["where"]]
    rows = [r for r in t.rows if all(c -> cell(r, c.first) == c.second, conds)]
    check(!isempty(rows), "no row of $(a["file"]) matches where = $(a["where"])")
    vals = [tryparse(Float64, cell(r, j)) for r in rows]
    near(v) = v !== nothing && abs(v - a["value"]) <= a["atol"]
    pass = a["quantifier"] == "all" ? all(near, vals) : any(near, vals)
    check(
        pass,
        "column '$(a["column"])' of $(length(rows)) selected rows of $(a["file"]): observed $vals, expected $(a["value"]) within $(a["atol"]) for $(a["quantifier"])",
    )
end

const CHECKS = Dict(
    "exit_code" => check_exit_code,
    "stage_sequence" => check_stage_sequence,
    "files_exact" => check_files_exact,
    "column_nonzero" => check_column_nonzero,
    "objective_differs_from_base" => check_objective_differs_from_base,
    "row_match" => check_row_match,
)

function assert_fixture(fx::Fixture, ctx)
    for (i, a) in enumerate(fx.asserts)
        kind = a["kind"]
        try
            CHECKS[kind](a, ctx)
        catch e
            e isa CheckFailed || rethrow()
            fail(1, "$(fx.name): [[assert]] #$i ($kind) failed: $(e.msg)")
        end
    end
end

# ------------------------------------------------------------- generate / verify

# The TempoResolucaoSeg cells are wall-clock times; every other byte must reproduce.
function mask_tempo(s)
    lines = split(s, '\n')
    k = column_line_index(lines)
    j = findfirst(==("TempoResolucaoSeg"), split(chopsuffix(lines[k], "\r"), ';'))
    j === nothing && return s
    for i in k+1:length(lines)
        cells = split(lines[i], ';')
        length(cells) >= j || continue
        cells[j] = endswith(cells[j], "\r") ? "<t>\r" : "<t>"
        lines[i] = join(cells, ';')
    end
    join(lines, '\n')
end

function same_bytes(rel, stored, fresh)
    basename(rel) == "resultado_processo_iter.csv" ?
    mask_tempo(String(copy(stored))) == mask_tempo(String(copy(fresh))) : stored == fresh
end

function first_difference(stored, fresh)
    a, b = split(String(copy(stored)), '\n'), split(String(copy(fresh)), '\n')
    for i in 1:max(length(a), length(b))
        x, y = get(a, i, "<end of file>"), get(b, i, "<end of file>")
        x == y || return "line $i: stored $(repr(x)), regenerated $(repr(y))"
    end
    "no differing line"
end

function verify(fx::Fixture, owned)
    stored = snapshot(joinpath(fx.dir, "oracle"), "oracle")
    fx.base && merge!(stored, snapshot(joinpath(fx.dir, "inputs"), "inputs"))
    problems = String[]
    for rel in sort!(collect(union(keys(owned), keys(stored))))
        if !haskey(stored, rel)
            push!(problems, "$rel: regenerated but not stored")
        elseif !haskey(owned, rel)
            push!(problems, "$rel: stored but not regenerated")
        elseif !same_bytes(rel, stored[rel], owned[rel])
            push!(
                problems,
                rel == "oracle/cli.log" ? "$rel: differs, first at $(first_difference(stored[rel], owned[rel]))" :
                "$rel: differs",
            )
        end
    end
    isempty(problems) ||
        fail(1, "$(fx.name): verify mismatch against the stored oracle:\n  " * join(problems, "\n  "))
end

function write_owned(fx::Fixture, owned)
    for sub in unique(first.(splitpath.(keys(owned))))
        rm(joinpath(fx.dir, sub); recursive = true, force = true)
    end
    for (rel, bytes) in owned
        path = joinpath(fx.dir, rel)
        mkpath(dirname(path))
        write(path, bytes)
    end
end

function write_provenance(fx::Fixture, owned, opts, tool)
    sha256sum(files) = join(
        ["$(bytes2hex(SHA.sha256(files[rel])))  $rel" for rel in sort!(collect(keys(files)))],
        "\n",
    )
    overlay = snapshot(joinpath(fx.dir, "overlay"), "overlay")
    open(joinpath(fx.dir, "PROVENANCE.md"), "w") do io
        println(io, "# Provenance: ", fx.name, "\n")
        println(io, "Written by `tools/regen_oracle_goldens.jl`. The oracle is identified by its commit SHA only.\n")
        println(io, "- Oracle commit: `", tool.sha, "`")
        println(io, "- rustc: `", tool.rustc, "`")
        println(io, "- cargo: `", tool.cargo, "`")
        println(io, "- highs-sys (oracle Cargo.lock): `", tool.highs_sys, "`")
        println(io, "- Command: `", opts.cmdline, "`\n")
        println(io, "## Overlay files (hand-authored inputs)\n")
        println(io, isempty(overlay) ? "None.\n" : "```text\n$(sha256sum(overlay))\n```\n")
        println(io, "## Generated files (sha256 of the committed bytes)\n")
        println(io, "```text\n$(sha256sum(owned))\n```")
    end
end

function write_new_fixture(fx::Fixture, owned)
    for rel in ("expected", "DIVERGENCES.toml")
        ispath(joinpath(fx.dir, rel)) &&
            fail(1, "$(fx.name): oracle/ is absent but $rel exists; $rel is Julia-owned and is never regenerated")
    end
    mkpath(joinpath(fx.dir, "expected"))
    for (rel, bytes) in owned
        startswith(rel, "oracle/RESULTADOS/") && write(joinpath(fx.dir, "expected", basename(rel)), bytes)
    end
    write(joinpath(fx.dir, "DIVERGENCES.toml"), "schema_version = 1\n")
end

function process(fx::Fixture, opts, tool)
    mktempdir() do work
        case = joinpath(work, "case")
        mkdir(case)
        materialize(opts.oracle, fx, case)
        inputs = fx.base ? snapshot(case, "inputs") : Dict{String,Vector{UInt8}}()
        oracle_run = run_oracle(tool.bin, case, joinpath(work, "cli.log"))
        resdir = joinpath(case, "RESULTADOS")
        assert_fixture(
            fx,
            (;
                oracle_run...,
                resdir,
                base_resdir = joinpath(opts.fixtures, BASE, "oracle", "RESULTADOS"),
            ),
        )

        owned = merge(
            inputs,
            snapshot(resdir, "oracle/RESULTADOS"),
            Dict("oracle/cli.log" => Vector{UInt8}(oracle_run.log)),
        )
        mode = !isdir(joinpath(fx.dir, "oracle")) ? :generate : opts.overwrite ? :overwrite : :verify
        if mode == :verify
            verify(fx, owned)
        else
            mode == :generate && write_new_fixture(fx, owned)
            write_owned(fx, owned)
            write_provenance(fx, owned, opts, tool)
        end
        eprintln("[$(fx.name)] $mode ok: $(count(startswith("oracle/RESULTADOS/"), keys(owned))) result files, $(length(fx.asserts)) assertions passed")
    end
end

function main(args)
    opts = parse_args(args)
    sha = preflight(opts.oracle)
    fixtures = discover(opts)
    mktempdir() do target
        eprintln("building the oracle at $PIN (cargo build --release --locked, external target dir)")
        tool = (; sha, build_oracle(opts.oracle, target)...)
        for fx in fixtures
            process(fx, opts, tool)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        main(ARGS)
    catch e
        e isa Failure || rethrow()
        eprintln(e.msg)
        exit(e.code)
    end
end
