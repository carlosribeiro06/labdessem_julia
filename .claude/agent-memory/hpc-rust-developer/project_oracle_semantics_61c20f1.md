---
name: oracle-semantics-61c20f1
description: Empirically verified behaviour of the labdessem_rust oracle at 61c20f1 that the Julia port and its goldens depend on (dual signs, CMB bug, golden provenance, variant recipes)
metadata:
  type: project
---

Verified 2026-10-28 by building the pinned oracle out-of-tree and running it on git-archived copies of 24Barras (no Rust changes).

- `examples/**/RESULTADOS/` is gitignored in labdessem_rust: the "golden" files are untracked local artifacts. The pinned build regenerates them byte-identical except `TempoResolucaoSeg`; the stale `resultado_fpha_computed.csv` came from an earlier computed-mode run.
- good_lp turns every `>=` row into `-expr <= -rhs`, so Rust's reported dual of any `>=` row is the negative of JuMP's. Equality and `<=` rows match JuMP (HiGHS.jl = sense * rowdual).
- Consequence: Rust CMB uses `dual(upper) + dual(lower)` = JuMP `dual(upper) - dual(lower)`. It is correct when the upper flow-cut row binds and sign-inverted when the lower row binds (finite-difference proof: bus 14 true 285.1059 vs Rust 14.8941 with LINHA-23 at 400 MW, UCT=0). Invisible on 24Barras (max line loading 71%).
- No range rows (single-sense LinearConstraint), no free rows, no unresolved terms on 24Barras in any mode; `NumeroRestricoes=7366` = 4102 model rows (incl. 2 empty marker rows) + 3264 flow-cut rows.
- `FPHA=computed` on 24Barras makes the oracle exit 1 (infeasible even with slacks); with `EngMax=0` it solves. `TON_Residual=1` alone is inert. `opcao_execucao=1` alone never reaches LP-FIXED.

**Why:** these facts decide golden validity and replicate-or-fix rulings for the rust-parity-port plan, and they took a pinned build plus finite-difference experiments to establish.
**How to apply:** check the plan's ADRs before re-deriving. Regenerate goldens only from the pinned binary on git-archived inputs, never by copying the oracle's RESULTADOS. Treat CMB/CMO on congested variants as diverging from the oracle unless replicated. See [[rust-parity-port]].
