# Test fixtures

This directory holds the vendored study cases that the golden tests run. For each case it also holds the reference implementation's (the oracle's) outputs, the Julia-owned snapshot of the expected outputs, and a ledger that attributes every difference between the two. This README is the contract for three consumers: the oracle regeneration script (`tools/regen_oracle_goldens.jl`), the golden comparator and the divergence-ledger checker. Every rule below is normative.

- **Oracle.** The oracle is the Rust implementation `labdessem_rust` pinned at commit `61c20f1` (`61c20f10412a50b9b33bb6fdfe1a78d0cba4b52c`). Every fixture is generated from that commit and no other.
- **Closed schema.** The directory layout, the `fixture.toml` fields and assertion kinds, and the `DIVERGENCES.toml` fields and kinds are closed sets. To add an assertion kind, a ledger kind or a field, this README must be edited first.
- **Toolchains.** Only the regeneration script needs a Rust toolchain and an oracle checkout. `Pkg.test()` must never need either.

## Fixtures

There are eleven fixtures: the base case and ten variants. A variant is the base case with a few input files replaced. Each fixture's `overlay/` files and its `fixture.toml` are the authority on what it changes. This table only summarizes them.

| Fixture | Directory | Change against `24Barras` | Path it exercises |
|---|---|---|---|
| `24Barras` | `test/fixtures/24Barras/` | none (the base case) | single MILP with network: `MILP#1`, then `LP-CALC-CMO#1`; 13 result files |
| `iterative-lpfixed-slack` | `test/fixtures/variants/iterative-lpfixed-slack/` | `opcao_execucao = 1`; LINHA-10 (buses 6-10) capacity 600 to 400 MW | iterative mode reaching LP-FIXED with a flow slack |
| `iterative-lpfixed-clean` | `test/fixtures/variants/iterative-lpfixed-clean/` | `opcao_execucao = 1`; LINHA-10 capacity 600 to 410 MW | iterative mode reaching LP-FIXED without a slack |
| `rede0` | `test/fixtures/variants/rede0/` | `rede = 0` | the no-network path; 9 result files |
| `uch` | `test/fixtures/variants/uch/` | `UCH = 1` | hydro unit commitment |
| `ton-residual` | `test/fixtures/variants/ton-residual/` | `TON_Residual = 1`; synthetic `OPER_CUSTO_RESIDUAL.csv` (100 R$/MWh in both submarkets) | thermal residual cost |
| `fpha-computed` | `test/fixtures/variants/fpha-computed/` | `FPHA = "computed"`, `EngMax = 0` | computed FPHA planes; 14 result files, `resultado_fpha_computed.csv` included |
| `slack-flow` | `test/fixtures/variants/slack-flow/` | LINHA-11 (buses 7-8) capacity 600 to 1 MW | flow-limit slack |
| `slack-oplimit` | `test/fixtures/variants/slack-oplimit/` | `rede = 0`; `OPER_REST_LIM.csv` with FURNAS GER bounds [5000, 6000] MW in periods 1-2 | operational-limit slack on the no-network path, where the oracle's records are correct; 9 result files |
| `slack-combined` | `test/fixtures/variants/slack-combined/` | LINHA-1 (buses 1-2) capacity 600 to 1 MW; the `OPER_REST_LIM.csv` of `slack-oplimit`; `rede` stays 1 | flow and operational-limit slacks together; pins the oracle's misread of the shared slack columns |
| `congested-linha23` | `test/fixtures/variants/congested-linha23/` | `UCT = 0`; LINHA-23 (buses 14-16) capacity 600 to 400 MW | a binding lower flow cut without slack |

## Layout

```text
test/fixtures/
├── README.md                     this contract
├── 24Barras/                     the base case
│   ├── fixture.toml              name, description, assertions (hand-written)
│   ├── inputs/                   the base case root
│   │   ├── CAD/
│   │   ├── OPER/
│   │   └── study_config.json
│   ├── oracle/
│   │   ├── RESULTADOS/           the oracle's result files
│   │   └── cli.log               the oracle's stdout+stderr, normalized
│   ├── expected/                 the Julia-owned snapshot of the result files
│   ├── PROVENANCE.md
│   └── DIVERGENCES.toml
└── variants/
    └── <name>/                   one directory per variant
        ├── fixture.toml
        ├── overlay/              full-file replacements, relative to the case root
        │   ├── study_config.json         (example)
        │   └── OPER/OPER_LINHA.csv       (example)
        ├── oracle/
        │   ├── RESULTADOS/
        │   └── cli.log
        ├── expected/
        ├── PROVENANCE.md
        └── DIVERGENCES.toml
```

1. The base case lives at `test/fixtures/24Barras/`. Every variant lives at `test/fixtures/variants/<name>/`. `<name>` must be kebab-case and must equal the `name` field of the variant's `fixture.toml`. Only the base case keeps the name `24Barras`.
2. A fixture directory is identified by its `fixture.toml`. Tools discover fixtures as `24Barras/fixture.toml` and `variants/*/fixture.toml`.
3. A **case root** is a directory that holds `CAD/`, `OPER/` and `study_config.json`: the input that the oracle CLI and the Julia pipeline run on. `24Barras/inputs/` is the base case root. It never contains `RESULTADOS/`.
4. A variant has no `inputs/`. Its `overlay/` holds only the files the variant changes. Each one is a complete file stored at its path relative to the case root, for example `overlay/study_config.json` or `overlay/OPER/OPER_LINHA.csv`. An overlay file replaces the base file at the same path as a whole. Overlays never patch part of a file and never delete one.
5. To **materialize** a case, copy the base case root into a fresh `mktempdir()`, then copy every file under the variant's `overlay/` to the same relative path, replacing the base file. The regeneration script takes the base case root from the pinned oracle commit (`git archive 61c20f1 examples/24Barras/CAD examples/24Barras/OPER examples/24Barras/study_config.json`), never from the oracle's untracked `RESULTADOS/`. The golden tests take it from `24Barras/inputs/`, which holds the same bytes.
6. Every copy is byte-for-byte, binary inputs (`OPER_FCF.bin`, `inflow_history.parquet`) included. Nothing is re-encoded. An overlay derived from a base file keeps that file's encoding, byte-order mark and line endings, and changes only the edited rows. The base `OPER/OPER_LINHA.csv` has a UTF-8 byte-order mark and CRLF line endings. Fixture files are committed without line-ending conversion.
7. Neither the oracle CLI nor the Julia pipeline ever runs on a directory under `test/fixtures/`. Both run on a materialized case root in a temporary directory, because the CLI writes `CASE_DIR/RESULTADOS`. No test writes under `test/fixtures/`, with one exception: a golden test run in snapshot-update mode writes `expected/` (see Update path).
8. `oracle/RESULTADOS/` and `expected/` are flat directories of result files with no subdirectories.

## Ownership

| Path | Written by | Rule |
|---|---|---|
| `fixture.toml` | hand, in the change that creates or redesigns the fixture | No tool writes it. |
| `overlay/**` | hand, in the change that creates or redesigns the fixture | Byte-exact (Layout rule 6). Changing it is a fixture redesign, which regenerates `oracle/` with `--overwrite`. |
| `inputs/**` (base only) | `tools/regen_oracle_goldens.jl` only | Immutable otherwise. Byte-identical to the pinned commit's `examples/24Barras` inputs. |
| `oracle/RESULTADOS/*` | `tools/regen_oracle_goldens.jl` only | Immutable otherwise. Never edited by hand or by a test. |
| `oracle/cli.log` | `tools/regen_oracle_goldens.jl` only | Immutable otherwise. Normalized before it is written or compared (below). No assertion and no test reads it. |
| `PROVENANCE.md` | `tools/regen_oracle_goldens.jl` only | Identifies the oracle by commit SHA only (below). |
| `expected/*` | the script once, when the fixture is created (a byte copy of `oracle/RESULTADOS/*`); afterwards only a golden test run with `LABDESSEM_UPDATE_SNAPSHOTS=1` | Julia-owned. Changes only in a ticket that also edits `DIVERGENCES.toml`. Never edited by hand. `--overwrite` never touches it. |
| `DIVERGENCES.toml` | the script once, when the fixture is created (`schema_version = 1`, no entries); afterwards by hand | Edited in the same ticket as the `expected/` update it attributes. `--overwrite` never touches it. |

`oracle/` is written once, from the pinned commit. `expected/` is never re-baselined from a different oracle commit. Re-pinning the oracle is a separate decision: it changes the script's pin and regenerates every fixture.

### oracle/cli.log

- The script runs the oracle CLI with stdout and stderr redirected to one shared file handle (one open file passed as both streams), so line order follows the oracle's own write order. Capturing two pipes and merging them in Julia is forbidden, because the asynchronous copy can reorder lines between runs.
- The captured text is normalized before it is written and before it is compared. The mask list is applied in this order:
  1. Every occurrence of the materialized case directory becomes `<CASE_DIR>`. Both the path as passed to the CLI and its `realpath` are replaced, the longer one first when one is a prefix of the other. This covers the banner `Case:` line and the summary `Output:` line.
  2. `solve time = <digits>.<digits> s` (regex `solve time = \d+\.\d+ s`) becomes `solve time = <t> s`.
  3. `time = <digits>.<digits>s` (regex `time = \d+\.\d+s`) becomes `time = <t>s`.
- On the pinned oracle these three masks cover every volatile field. A `cli.log` difference that survives normalization fails verify mode. It is fixed by extending the script's mask list in a reviewed change, never by excluding `cli.log` from verification or from the `PROVENANCE.md` hashes.
- No assertion reads `cli.log`. Stages and statuses are read from `resultado_processo_iter.csv`. `cli.log` is evidence only.

### PROVENANCE.md

The script writes `PROVENANCE.md` in generate and overwrite mode. It must contain:

- the oracle commit SHA from `git rev-parse HEAD` in the oracle checkout. The oracle is identified by this SHA only, never by the version the CLI banner prints: at the pinned v0.11.0 release commit the binary prints `LABDESSEM v0.8.0`, so the banner version identifies nothing;
- the toolchain: `rustc --version`, `cargo --version`, and the `highs-sys` version from the oracle's `Cargo.lock`;
- the exact script command line;
- the overlay file list with the sha256 of each file. Every overlay file is a hand-authored input, so synthetic inputs such as the `ton-residual` residual-cost table are recorded here;
- the sha256 of every file the script owns in the fixture: `inputs/**` (base only), `oracle/RESULTADOS/*` and the normalized `oracle/cli.log`, each computed on the committed bytes.

## fixture.toml

`fixture.toml` names the fixture and lists the properties the oracle run must show. The regeneration script evaluates every `[[assert]]` table against the oracle run of the materialized case on every run, in both generate and verify mode, before it writes anything. One failed assertion stops the script.

| Field | Type | Required | Definition | Example |
|---|---|---|---|---|
| `name` | string | yes | The fixture name. Must equal the directory name. | `name = "uch"` |
| `base` | string | yes for a variant; must be absent in `24Barras` | The fixture whose case root the overlay applies to. The only allowed value is `"24Barras"`. | `base = "24Barras"` |
| `description` | string | yes | What the fixture changes against its base and why. | `description = "Hydro unit commitment enabled (UCH = 1)."` |
| `[[assert]]` | array of tables | yes | One table per property. Each has `kind` plus the fields of that kind. | `kind = "exit_code"` |

Every fixture must include an `exit_code`, a `stage_sequence` and a `files_exact` assertion. Its assertions must also pin the property the fixture exists to exercise, such as a slack status, a non-zero column, a binding flow, a changed objective or a file set. No other top-level field and no other assertion field exists. A reader must reject an unknown field with an error that names the file and the field.

`kind` must be one of `exit_code`, `stage_sequence`, `files_exact`, `column_nonzero`, `objective_differs_from_base`, `row_match`:

| `kind` | Fields | Definition |
|---|---|---|
| `exit_code` | `value` (integer) | The oracle CLI process exits with status `value`. |
| `stage_sequence` | `value` (array of strings) | Every data row of `resultado_processo_iter.csv`, in file order and rendered as `<Etapa>#<Iteracao> <StatusSolucao>` from the cells as printed, gives exactly `value`: same length, same order. |
| `files_exact` | `value` (array of strings) | The set of file names in the run's `RESULTADOS/` equals `value`, with none missing and none extra. `value` must be sorted alphabetically and have no duplicates. |
| `column_nonzero` | `file`, `column` (strings) | `file` exists and has `column`, and in at least one data row the `column` cell parses as a number other than zero (`0.000000` and `-0.0000` count as zero). |
| `objective_differs_from_base` | `stage` (string, an `Etapa` value), `min_abs_delta` (number, at least 0) | `abs(obj - obj_base) >= min_abs_delta`. `obj` is the `ValorFuncaoObjetivo` of the row whose `Etapa` equals `stage` in this run's `resultado_processo_iter.csv`. `obj_base` is the same cell in the base fixture's stored `oracle/RESULTADOS/resultado_processo_iter.csv`. `stage` must occur in exactly one row of each file. Valid only in a variant. |
| `row_match` | `file`, `where` (inline table, column name to exact text), `column`, `value` (number), `atol` (number, at least 0), `quantifier` (`"all"` or `"any"`) | The rows of `file` whose cells equal every `where` entry as exact text are selected, and at least one row must be selected. With `"all"` every selected row, and with `"any"` at least one, has a `column` cell that parses as a number within `atol` of `value`. |

`atol` in `row_match` bounds that one property check on the oracle run. It is not a comparison tolerance. `fixture.toml` has no field that changes the comparison tiers: tolerances are global (Comparison rules), and a difference the tiers do not tolerate goes to the ledger.

One `[[assert]]` table per kind:

```toml
[[assert]]
kind = "exit_code"
value = 0

[[assert]]
kind = "stage_sequence"
value = ["MILP#1 OPTIMAL", "LP-CALC-CMO#1 OPTIMAL"]

[[assert]]
kind = "files_exact"
value = ["resultado_cmobar.csv", "resultado_cmosist.csv", "resultado_elevatorias.csv", "resultado_fcf_eco.csv", "resultado_hidreletricas.csv", "resultado_inviabilidade_lim.csv", "resultado_inviabilidade_rede.csv", "resultado_linhas_adicionadas.csv", "resultado_processo_iter.csv", "resultado_rede.csv", "resultado_renovaveis.csv", "resultado_rest_lim.csv", "resultado_termicas.csv"]

[[assert]]
kind = "column_nonzero"
file = "resultado_termicas.csv"
column = "CustoResidual"

[[assert]]
kind = "objective_differs_from_base"
stage = "MILP"
min_abs_delta = 0.01

[[assert]]
kind = "row_match"
file = "resultado_rede.csv"
where = { Linha = "LINHA-23" }
column = "FluxoMW"
value = -400.0
atol = 1e-4
quantifier = "all"
```

The following complete example shows the shape of a variant's file. The fixture's own file is the authority on its content.

```toml
name = "iterative-lpfixed-clean"
base = "24Barras"
description = """
Iterative mode (opcao_execucao = 1) with LINHA-10 (buses 6-10) tightened from 600 to 410 MW. \
The flow-cut loop adds LINHA-10 and the run reaches LP-FIXED without any slack.\
"""

[[assert]]
kind = "exit_code"
value = 0

[[assert]]
kind = "stage_sequence"
value = ["LP#1 OPTIMAL", "MILP#1 OPTIMAL", "LP-FIXED#1 OPTIMAL", "LP-CALC-CMO#1 OPTIMAL"]

[[assert]]
kind = "files_exact"
value = ["resultado_cmobar.csv", "resultado_cmosist.csv", "resultado_elevatorias.csv", "resultado_fcf_eco.csv", "resultado_hidreletricas.csv", "resultado_inviabilidade_lim.csv", "resultado_inviabilidade_rede.csv", "resultado_linhas_adicionadas.csv", "resultado_processo_iter.csv", "resultado_rede.csv", "resultado_renovaveis.csv", "resultado_rest_lim.csv", "resultado_termicas.csv"]

[[assert]]
kind = "row_match"
file = "resultado_linhas_adicionadas.csv"
where = { NomeLinha = "LINHA-10" }
column = "CapacidadeMW"
value = 410.0
atol = 1e-4
quantifier = "any"
```

## DIVERGENCES.toml

`DIVERGENCES.toml` is the fixture's executable divergence ledger, schema version 1. It starts with `schema_version = 1`, followed by zero or more `[[divergence]]` tables. Each entry attributes a set of differences between `expected/` and `oracle/RESULTADOS/` to a recorded decision (see Cross-check). Every fixture has its own ledger, and an entry never covers another fixture.

| Field | Type | Required | Definition | Example |
|---|---|---|---|---|
| `schema_version` | integer, top level | yes | The ledger schema version. Must be `1`. | `schema_version = 1` |
| `id` | string | yes | The entry's name, unique within the file. Failure messages cite it. | `id = "cmobar-period-labels"` |
| `file` | string | yes | A result file name, as it appears in `oracle/RESULTADOS/` and `expected/`. | `file = "resultado_cmobar.csv"` |
| `kind` | string | yes | The kind of difference (kinds table below). | `kind = "key-shift"` |
| `column` | string | for `value`, `key-shift`, `degenerate-tie` | The column that holds the difference. Not used by `row-added` and `row-removed`. | `column = "Periodo"` |
| `match` | inline table, column name to string | no; absent means empty | Selects rows by the exact text of their key cells (names, codes, periods). Empty or absent means all rows of `file`. | `match = { NomeBarra = "BARRA 2" }` |
| `adr` | string, `ADR-` followed by three digits | yes | The architecture decision record the difference traces to. | `adr = "ADR-027"` |
| `ticket` | string | yes | The ticket that introduced the entry. | `ticket = "ticket-104"` |
| `justification` | string | yes | Why the difference is intended. | `justification = "Julia writes 1-based original periods."` |
| `evidence` | string | for `degenerate-tie` | Proof that the tie is degenerate: the objectives are equal within the tiers, and the oracle's solution is feasible in the Julia model. | `evidence = "Objective equal to 1e-9 relative; oracle flows feasible in the Julia LP."` |
| `offset` | integer | for `key-shift` | The shift in the `column` cells: `expected = oracle + offset`. | `offset = 1` |

`kind` must be one of `value|row-added|row-removed|key-shift|degenerate-tie`:

| `kind` | Definition |
|---|---|
| `value` | On rows matching `match`, a cell in `column` differs beyond the comparison tiers (numeric) or as text, because of a recorded decision. |
| `row-added` | Rows matching `match` exist in `expected/` and not in `oracle/RESULTADOS/` (Julia writes rows that the oracle omits). |
| `row-removed` | Rows matching `match` exist in `oracle/RESULTADOS/` and not in `expected/` (Julia omits rows that the oracle writes). |
| `key-shift` | On rows matching `match`, the integer cells in `column` satisfy `expected = oracle + offset`. |
| `degenerate-tie` | Same as `value`, but the difference comes from an alternative optimum of a degenerate problem, not from a decision. `evidence` is required. |

`match` is evaluated on the `oracle/RESULTADOS/` row, except for `row-added`, whose rows exist only in `expected/`. `match` values must be TOML strings and are compared with cells as exact text. No other entry field exists. A reader must reject an unknown field with an error that names the file, the entry `id` and the field.

Complete example. The entries are illustrative: they show the syntax and are not the content of any fixture's ledger.

```toml
schema_version = 1

[[divergence]]
id = "cmobar-period-labels"
file = "resultado_cmobar.csv"
kind = "key-shift"
column = "Periodo"
offset = 1
adr = "ADR-027"
ticket = "ticket-104"
justification = "Julia writes 1-based original periods; the oracle writes 0-based internal periods."

[[divergence]]
id = "cmobar-units"
file = "resultado_cmobar.csv"
kind = "value"
column = "CMB"
adr = "ADR-008"
ticket = "ticket-105"
justification = "CMB is reported in R$/MWh (divided by the period duration), the same scale as CMO."

[[divergence]]
id = "cmobar-slack-bus"
file = "resultado_cmobar.csv"
kind = "row-added"
match = { CodigoBarra = "1" }
adr = "ADR-009"
ticket = "ticket-106"
justification = "Julia emits the slack-bus CMB, which the oracle omits."

[[divergence]]
id = "lim-misread-records"
file = "resultado_inviabilidade_lim.csv"
kind = "row-removed"
match = { NomeUsina = "FURNAS", Variavel = "GER" }
adr = "ADR-019"
ticket = "ticket-100"
justification = "The oracle writes records read from flow-slack columns; Julia's separate slack variables do not produce them."

[[divergence]]
id = "linha7-flow-tie"
file = "resultado_linhas_adicionadas.csv"
kind = "degenerate-tie"
column = "FluxoMW"
match = { NomeLinha = "LINHA-7" }
adr = "ADR-038"
ticket = "ticket-095"
justification = "The flow-cut loop reached an alternative optimum with the same objective."
evidence = "ValorFuncaoObjetivo equal within rtol 1e-7; the oracle's flows satisfy every Julia row within 1e-9."
```

## Comparison rules

### Reading result files

- Result files are `;`-separated text. A file whose first line starts with `ONS - Operador` begins with a header block: `ONS - Operador Nacional do Sistema Eletrico`, `LabDessem`, a blank line, `Descricao das colunas:`, one `column: description` line per column, and a blank line. The header block ends at its second blank line, and the next line is the column line. A file without the header starts with the column line. Header description lines can contain `;` (`resultado_termicas.csv` has one), so the column line is the first line after the header block, never the first line that contains `;`.
- The header block is never compared. Julia writes it on every file, while the oracle omits it on `resultado_cmobar.csv`, `resultado_rede.csv` and `resultado_linhas_adicionadas.csv`.
- Every line after the column line is a data row. A trailing `\r` is removed, cells are split on `;`, and cells are kept as exact text with no trimming (oracle names carry padding spaces).
- Data rows are numbered from 1: row 1 is the first line after the column line. Failure messages use this row index.

### Tiers

A comparison takes a reference side R (`oracle/RESULTADOS/` in the ledger pass, `expected/` in the golden pass) and a candidate side C.

- The file sets must be equal, column lines must be identical, and row counts must be equal. With equal counts, rows are compared pairwise in file order.
- A cell is numeric when the R cell contains `.` and both cells parse as `Float64`. A numeric cell passes when `abs(c - r) <= atol + rtol * abs(r)`, with `rtol = 1e-7` and `atol = 1.5 * 10^-d`, where `d` is the number of decimals printed in the R cell. A cell written with an exponent uses `atol = 0`. `-0.000000` equals `0.000000`, `NaN` equals `NaN`, and `inf`/`-inf` compare as text.
- `ValorFuncaoObjetivo` uses `atol = 0` and `rtol = 1e-7`.
- Every other cell is compared as exact text. This covers keys, names, periods and statuses.
- The columns `TempoResolucaoSeg`, `NumeroRestricoes` and `NumeroVariaveis` are never compared.
- The base fixture's oracle output does not contain `resultado_fpha_computed.csv`, because the constant-productivity run does not write it. Julia must not write it in that mode, and the file-set rule enforces both.
- Tolerances are global. No fixture, test or ledger entry widens them. A difference beyond them is either a defect or a ledger entry.

### Fixture-specific modes

- **Commitment replay.** For `24Barras` and for the variants whose MILP or flow-cut loop can reach alternative optima (`iterative-lpfixed-slack`, `iterative-lpfixed-clean`, `uch`, `ton-residual`), commitment replay is the primary check for the duals, CMO and CMB. The oracle's unit commitment (`StatusOn` of the unit rows of `resultado_termicas.csv`, and of `resultado_hidreletricas.csv` when `UCH = 1`) is injected into Julia's LP-CALC-CMO stage. The resulting objective, `PiDemanda`/`CMO`, `CMB` and `PiBalHidr` are then compared against `expected/` with the tiers above. In these variants, primal and cut-set differences against the oracle are covered only by `degenerate-tie` entries with evidence.
- **FPHA plane sets.** In `fpha-computed`, the oracle comparison of `resultado_fpha_computed.csv` is plane-set-wise, not row by row, and plane differences are never ledgered.
  - Planes are canonicalized per plant in lexicographic order on (`gamma_0`, `gamma_v`, `gamma_q`, `gamma_s`), so `plane_index` is not compared. `codigo_usina` and `nome_usina` are exact, and `alpha` uses the numeric tier.
  - With equal plane counts, the canonical planes compare at abs `1e-6` on `gamma_0`/`gamma_q` and abs `1e-9` on `gamma_v`/`gamma_s`, and the deviation metrics compare within `1e-3` MW.
  - With different plane counts, the min-envelopes of both plane sets are evaluated on the plant's fitting grid and must agree within `1e-3` MW.
  - The fixture's simulation outputs differ from the oracle by decision (the FPHA correction factor is applied once, not twice). Those differences are ledgered like any other divergence.

## Cross-check

Each fixture is checked in two passes. Both use the tiers above, never byte equality, so a last-digit change within the tiers needs no ledger entry. The golden tests run inside the default `Pkg.test()`.

1. **Golden pass.** Julia's result files for the materialized case are compared against the fixture's `expected/` (reference side `expected/`). The pass must report no difference.
2. **Ledger pass.** `expected/` is compared against `oracle/RESULTADOS/` (reference side `oracle/`), and the differences are checked against the fixture's `DIVERGENCES.toml`:
   - **Coverage.** Every difference that the tiers do not tolerate must be covered by at least one entry.
   - **Staleness.** Every entry must cover at least one current difference. An entry that covers none is stale, and the test fails.
   - Entries are evaluated independently, and one difference may be covered by several entries.

What each kind covers:

| `kind` | Covers |
|---|---|
| `value`, `degenerate-tie` | A numeric or text difference in `file` and `column`, on a row that matches `match`. |
| `row-added` | The row-count difference of `file`, plus every difference located in rows that match `match` and exist only in `expected/`. |
| `row-removed` | The row-count difference of `file`, plus every difference located in rows that match `match` and exist only in `oracle/RESULTADOS/`. |
| `key-shift` | A text difference in `file` and `column`, on a row that matches `match`, where both cells parse as integers and `expected = oracle + offset`. |

No kind covers a missing file, an extra file or a different column line. Such a difference always fails.

Schema errors (a wrong `schema_version`, a missing required field, an unknown `kind` or field, a malformed `adr`, a non-integer `offset`, a duplicate `id`) are raised when the ledger is loaded, before any comparison runs.

## Update path

There are two procedures. Regenerating the oracle is rare. Updating the Julia snapshot happens for every intended output change.

### The regeneration script

Prerequisites: an oracle checkout at commit `61c20f1` with a clean worktree, and a Rust toolchain (`rustc`, `cargo`) on `PATH`. The checkout defaults to `../labdessem_rust`, relative to the repository root. `Pkg.test()` never needs either.

```sh
julia --startup-file=no tools/regen_oracle_goldens.jl [--oracle PATH] [--fixtures DIR] [--only NAME]... [--overwrite]
```

| Mode | When | What it does |
|---|---|---|
| generate | `oracle/` is absent | Writes `oracle/RESULTADOS/*`, the normalized `oracle/cli.log`, `PROVENANCE.md`, `expected/` (a byte copy of `oracle/RESULTADOS/*`) and a `DIVERGENCES.toml` that holds only `schema_version = 1`. For the base fixture it also writes `inputs/`. |
| verify | `oracle/` is present and `--overwrite` is absent | Writes nothing. Compares every regenerated file (`inputs/**` of the base fixture, `oracle/RESULTADOS/*`, `oracle/cli.log`) byte-for-byte with the stored one, the normalized `cli.log` included, except the `TempoResolucaoSeg` column of `resultado_processo_iter.csv`. |
| overwrite | `oracle/` is present and `--overwrite` is given | Rewrites `oracle/`, `inputs/` and `PROVENANCE.md`. Never touches `expected/` or `DIVERGENCES.toml`. |

The script exits 0 when every selected fixture is generated or verified. It exits 1 on an assertion failure, a verification failure or a `fixture.toml` schema error, and 2 on a preflight failure (wrong commit or dirty checkout). It never writes into the oracle checkout: it builds in an external target directory and runs the CLI on a materialized case root.

### Create a fixture

1. Write `fixture.toml`, plus the `overlay/` files for a variant.
2. Run the script with `--only <name>` (generate mode). A variant that asserts `objective_differs_from_base` needs the base fixture's `oracle/` to exist first.
3. Run the same command again. Verify mode must exit 0 and change nothing.
4. Commit every generated file unmodified, without line-ending conversion.

### Regenerate or verify the oracle

1. Run the script without `--overwrite`. Verify mode must exit 0.
2. If verify mode reports a `cli.log` difference, it names the first differing line. That is a volatile field the masks miss: extend the script's mask list in a reviewed change, then verify again. Never exclude the file. Any other difference means the oracle run is not reproducible or an input changed. Investigate it, and never commit over it.
3. Use `--overwrite` only when a fixture is redesigned (its overlay changes) or the oracle is re-pinned. Then update the snapshot and the ledger as below.

### Update the Julia snapshot

Use this procedure for any intended change to Julia's results beyond the tiers: a divergence fix, a fixed oracle quirk, a solver or JuMP version change in `Manifest.toml`, or a fixture redesign.

1. Regenerate the oracle first if it changed (previous procedure).
2. Make the code change.
3. Run the golden tests with `LABDESSEM_UPDATE_SNAPSHOTS=1`. That run rewrites each affected fixture's `expected/` from Julia's results instead of comparing against it. Only this run writes `expected/`. Never edit `expected/` by hand, and never set the variable in a normal run.
4. In the same ticket, edit the `DIVERGENCES.toml` of every affected fixture. Add an entry that cites the decision for every new difference against the oracle, and remove every entry that became stale.
5. Review the `expected/` diff. Every difference between the old and new `expected/` that the tiers do not tolerate must lie in a file, column and rows attributed by a ledger entry added, edited or removed in this ticket.
6. Run `julia --project=. -e 'using Pkg; Pkg.test()'` without the variable. The golden pass must report no difference, and the ledger pass must report no uncovered difference and no stale entry.
7. Commit the code, `expected/` and `DIVERGENCES.toml` together.

## Failure messages

Every failure must name the items below. The wording around them is free.

| Consumer | Condition | The message names |
|---|---|---|
| regeneration script | preflight failure (exit 2) | the failed check and the pinned commit `61c20f1` |
| regeneration script | missing required field in `fixture.toml` (exit 1) | the file, the field and, inside an `[[assert]]`, its 1-based position and `kind` |
| regeneration script | unknown assertion `kind` (exit 1) | the file, the `kind` found and the allowed set: `exit_code, stage_sequence, files_exact, column_nonzero, objective_differs_from_base, row_match` |
| regeneration script | unknown field or invalid value, such as a `quantifier` outside `all, any` (exit 1) | the file, the field and the value |
| regeneration script | failed assertion (exit 1) | the fixture, the `kind` and the observed value |
| regeneration script | verify mismatch (exit 1) | every differing file and, for `cli.log`, the first differing line (line number, stored text, regenerated text) |
| regeneration script | external command failure | the command line and its captured stderr |
| golden comparator | difference in the golden pass | the fixture, file, row index, column, `expected/` value and Julia value; a file-level difference names the file and what differs (missing, extra, column line, both row counts) |
| ledger checker | `schema_version` missing or not `1` | the file and the value found |
| ledger checker | missing required field | the file, the entry `id` (its 1-based position when `id` is missing) and the field |
| ledger checker | unknown `kind` | the file, the entry `id`, the `kind` found and the allowed set: `value, row-added, row-removed, key-shift, degenerate-tie` |
| ledger checker | malformed field (an `adr` that is not `ADR-` plus three digits, a non-integer `offset`, a duplicate `id`, an unknown field) | the file, the entry `id`, the field and the value |
| ledger checker | stale entry | the file and the entry `id` |
| ledger checker | uncovered difference | the fixture, file, row index, column, oracle value and Julia (`expected/`) value |

Example shapes:

```text
test/fixtures/variants/uch/fixture.toml: [[assert]] #4 (objective_differs_from_base): missing required field 'min_abs_delta'
test/fixtures/24Barras/fixture.toml: [[assert]] #2: unknown kind 'stage_order'; allowed: exit_code, stage_sequence, files_exact, column_nonzero, objective_differs_from_base, row_match
test/fixtures/24Barras/DIVERGENCES.toml: entry 'cmobar-units': unknown kind 'values'; allowed: value, row-added, row-removed, key-shift, degenerate-tie
test/fixtures/24Barras/DIVERGENCES.toml: stale entry 'cmobar-units' covers no current difference
24Barras: uncovered difference in resultado_cmobar.csv row 17 column CMB: oracle 0.0514, julia 0.0257
```
