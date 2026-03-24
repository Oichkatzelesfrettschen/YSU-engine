# Python Auto-Explorer

This repo now has a first Python auto-explorer scaffold for the SASS RE
frontier:

- script:
  [`scripts/auto_explorer.py`](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/auto_explorer.py)
- search-space registry:
  [`auto_explorer_search_space.toml`](/home/eirikr/Github/YSU-engine/src/sass_re/auto_explorer_search_space.toml)
- queue helper:
  [`scripts/auto_explorer_queue.py`](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/auto_explorer_queue.py)
- first generated report:
  [`auto_explorer_20260322_141500`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_20260322_141500)
- first generated queue:
  [`auto_explorer_queue_20260322_143000`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_queue_20260322_143000)
- refreshed report after executing the top-ranked branch:
  [`auto_explorer_20260322_143500`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_20260322_143500)
- refreshed reports after the narrow SYS64 and bridge follow-ups:
  [`auto_explorer_20260322_171047`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_20260322_171047)
  and
  [`auto_explorer_20260322_171324`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_20260322_171324)

## Short answer

Yes. We have enough pattern to build and run a Python auto-explorer now.
The current frontier is structured enough that we do not need ONNX, TensorRT,
or a neural net for the first useful version.

The search problem is still sparse, discrete, and interpretable:

- symbolic-only raw-SASS boundary:
  `P2R.B1`, `P2R.B2`, `P2R.B3`
- runtime-safe combo frontier:
  async/cache backbone plus uniform helpers, block-red, warp helpers,
  divergent/reconvergent control, and dense 64-bit SYS-side atomic/store
  families

That makes a registry-driven Python explorer with classical feature extraction
and small surrogate models the right first architecture.

## Package categories

### 1. Core ingestion and CLI

Recommended:

- stdlib: `argparse`, `csv`, `json`, `pathlib`, `re`, `statistics`,
  `subprocess`, `tomllib`
- CLI / typing:
  - `typer`
  - `pydantic`
  - `rich`

Why:

- clean CLI
- stable typed config
- readable terminal summaries
- no hard dependency on heavyweight ML stacks

### 2. Tabular analysis

Recommended:

- `numpy`
- `pandas`
- `pyarrow`

Why:

- easy ingestion of `ncu.csv`, `ncu_stalls.csv`, and run matrices
- compact export of proposal tables and frontier snapshots

### 3. Graph and chain analysis

Recommended:

- `networkx`

Why:

- mnemonic bigram / trigram / anchor-window graphs
- adjacency-based novelty scoring
- family clustering over emitted SASS windows

### 4. Small surrogate models and proposal scoring

Recommended:

- `scikit-learn`
- `optuna`

Why:

- `RandomForestRegressor` is already enough to model:
  - cycles
  - long-scoreboard pressure
  - membar pressure
- `optuna` is enough for bounded discrete search over candidate frontier
  toggles

This is the current sweet spot. It is interpretable and stable on a small
dataset.

### 5. Optional ML packages

Installed here:

- `onnx`
- `onnxruntime`
- `torch`

Not required for v1.

Use them only if the frontier grows large enough that we want:

- learned embeddings of mnemonic chains
- a tiny policy model that predicts which probe mutation is most likely to
  expose a new regime
- offline inference only, with no training-time dependency on CUDA/TensorRT

### 6. Not needed first

Not installed here or not justified yet:

- `nevergrad`
- `xgboost`
- `lightgbm`
- TensorRT-backed neural policy search

The current corpus is too small and too interpretable to justify them.

## Installed package status on this workstation

Verified available:

- `numpy`
- `pandas`
- `networkx`
- `scikit-learn`
- `optuna`
- `onnx`
- `onnxruntime`
- `torch`
- `typer`
- `pydantic`

Missing:

- `polars`
- `nevergrad`
- `xgboost`
- `lightgbm`

## Why not borrow Cayley-Dickson math first

The hypercomplex / Cayley-Dickson material in `open_gororoba` is interesting,
but it is not the right first abstraction for this frontier.

For SASS RE, the dominant structure is not continuous geometry; it is a
discrete experiment graph:

- source-shape toggles
- flag toggles
- mnemonic-chain neighborhoods
- stall-regime transitions
- symbolic-only vs runtime-safe conversions

The useful pattern to borrow from `open_gororoba` is the explicit registry and
lineage style, not the algebra itself. That is why the explorer uses:

- a TOML search-space registry
- explicit candidate derivation metadata
- generated report artifacts under `results/runs/`

instead of trying to embed the frontier into octonions or higher doublings.

## Current explorer architecture

The first explorer does four things:

1. Ingest existing run artifacts:
   - `.sass`
   - `ncu.csv`
   - `ncu_stalls.csv`
2. Extract features:
   - async/cache backbone
   - uniform-helper chain
   - block-red
   - warp vote/match/redux
   - divergent/reconvergent control
   - 64-bit SYS family
   - direct SYS store
   - `-dlcm=cg`
   - depth
3. Fit a small surrogate when `scikit-learn` is present
4. Score the next runtime and symbolic candidates from the TOML registry

It now supports both Nsight Compute CSV layouts that appear in this repo:

- the older wide-column form
- the newer long `Metric Name` / `Metric Value` form

That parser fix matters because the newer bridge tranches were initially being
under-scored even though their `ncu` artifacts were valid.

## Current top-ranked next runtime candidates

From the first generated report:

- `uniform_blockred_sys64_store`
- `uniform_blockred_sys64_depth`
- `uniform_blockred_sys64_store_dlcm_cg`
- `narrow_atomg_sys64_dlcm_cg`
- `uniform_divergent_sys64`

And the symbolic boundary stays:

- `p2r_b1_literal_bank_retry`
- `p2r_b2_literal_bank_retry`
- `p2r_b3_literal_bank_retry`

## First executed explorer pick

The first ranked runtime candidate was executed directly:

- tranche:
  [`combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_143100`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_143100)
- probe:
  [`probe_combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe.cu`](/home/eirikr/Github/YSU-engine/src/sass_re/probes/probe_combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe.cu)

It validated the explorer's direction and widened the branch further than the
proposal requested. The emitted SASS now carries, in one executable kernel:

- `ULDC(.64)`
- `UIADD3`
- `ULOP3.LUT`
- `USHF.L.U32`
- `USHF.L.U64.HI`
- `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`
- `LDGDEPBAR`
- `DEPBAR.LE`
- `BAR.RED.*`
- `B2R.RESULT`
- `MATCH.ANY`
- `REDUX.*`
- `VOTE.ALL`
- `VOTE.ANY`
- `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
- `LDG.E.64.STRONG.SYS`
- `STG.E.64.STRONG.SYS`
- `MEMBAR.SC.SYS`
- `ERRBAR`
- `CCTL.IVALL`

and it also spontaneously picks up optimized `BSSY` and `BSYNC`.

Its first `ncu` profile is a heavy fused SYS-side regime:

- `1152` instructions
- `38` regs/thread
- `4096 B` static shared memory
- `smsp__cycles_elapsed.avg` about `12028.98`
- `long_scoreboard ~47.40%`
- `membar ~24.97%`
- `short_scoreboard ~1.09%`
- `barrier ~0.88%`
- `wait ~5.96%`

So the first executed explorer pick both validated the ranking and widened the
runtime frontier into a stronger fused family than the original non-divergent
proposal suggested.

## New bridge branches

Two newer runtime-safe branches now sit between the lighter uniform-helper
family and the heavier fused SYS-store family:

- uniform + divergent + SYS64 bridge:
  [`combo_uniform_divergent_atomg64sys_profile_safe_tranche_20260322_170855`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_divergent_atomg64sys_profile_safe_tranche_20260322_170855)
- divergent + SYS64 store bridge:
  [`combo_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_171218`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_171218)
- uniform + block-red + SYS64 depth bridge:
  [`combo_uniform_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_172135`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_172135)
- uniform + divergent + SYS64 bridge under `-dlcm=cg`:
  [`combo_uniform_divergent_atomg64sys_profile_safe_tranche_dlcm_cg_20260322_173400`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_divergent_atomg64sys_profile_safe_tranche_dlcm_cg_20260322_173400)
- uniform + divergent + block-red + SYS64 store bridge:
  [`combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_172130`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_172130)
- uniform + divergent + block-red + SYS64 store bridge under `-dlcm=cg`:
  [`combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_172203`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_172203)

The uniform-divergent bridge keeps:

- `ULDC.64`
- `UIADD3`
- `ULOP3.LUT`
- `USHF.L.U32`
- `USHF.L.U64.HI`
- `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`
- `LDGDEPBAR`
- `DEPBAR.LE`
- `VOTE.ANY`
- `LDG.E.64`

and profiles as:

- `1012` instructions
- `30` regs/thread
- `4096 B` static shared
- `cycles ~9553.06`
- `long_scoreboard ~20.56%`
- `membar ~31.67%`
- `short_scoreboard ~10.76%`

So it is a real midpoint regime: still `membar + latency`, but with a much
larger short-scoreboard component than the heavier store-side families.

The direct `-dlcm=cg` comparison for that lighter uniform-divergent bridge
under
`combo_uniform_divergent_atomg64sys_profile_safe_tranche_dlcm_cg_20260322_173400`
improves L2 hit rate to about `73.69%`, but cycles still worsen slightly to
about `9701.17`. So even on the lighter midpoint branch, policy changes
spelling and cache behavior more than it improves runtime.

The divergent SYS-store bridge keeps:

- `BSSY`
- `BSYNC`
- `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`
- `LDGDEPBAR`
- `DEPBAR.LE`
- `BAR.RED.*`
- `B2R.RESULT`
- `MATCH.ANY`
- `REDUX.*`
- `VOTE.ALL`
- `VOTE.ANY`
- `LDG.E.64.STRONG.SYS`
- `STG.E.64.STRONG.SYS`
- `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
- `MEMBAR.SC.SYS`
- `ERRBAR`
- `CCTL.IVALL`

and profiles as:

- `880` instructions
- `38` regs/thread
- `4096 B` static shared
- `cycles ~11159.66`
- `long_scoreboard ~44.26%`
- `membar ~25.15%`
- `short_scoreboard ~1.99%`
- `barrier ~1.32%`

That strongly suggests direct SYS load/store, not divergence alone, is what
pulls the branch back toward the heavier fused long-scoreboard + membar
regime.

The uniform + block-red + SYS64 depth bridge keeps:

- `ULDC(.64)`
- `UIADD3`
- `ULOP3.LUT`
- `USHF.L.U32`
- `USHF.L.U64.HI`
- `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`
- `LDGDEPBAR`
- `DEPBAR.LE`
- `BAR.RED.*`
- `B2R.RESULT`
- `MATCH.ANY`
- `REDUX.*`
- `VOTE.ALL`
- `VOTE.ANY`
- `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
- `MEMBAR.SC.SYS`
- `ERRBAR`
- `CCTL.IVALL`

and profiles as:

- `1236` instructions
- `36` regs/thread
- `4096 B` static shared
- `cycles ~12529.48`
- `long_scoreboard ~54.97%`
- `membar ~22.40%`
- `short_scoreboard ~0.99%`
- `barrier ~0.83%`

So the non-store uniform depth branch now behaves much more like a
long-scoreboard-heavy fused family than the earlier uniform-divergent bridge.

The uniform + divergent + block-red + SYS64 store bridge keeps:

- `ULDC(.64)`
- `UIADD3`
- `ULOP3.LUT`
- `USHF.L.U32`
- `USHF.L.U64.HI`
- `BSSY`
- `BSYNC`
- `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`
- `LDGDEPBAR`
- `DEPBAR.LE`
- `BAR.RED.*`
- `B2R.RESULT`
- `MATCH.ANY`
- `REDUX.*`
- `VOTE.ALL`
- `VOTE.ANY`
- `LDG.E.64.STRONG.SYS`
- `STG.E.64.STRONG.SYS`
- `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
- `MEMBAR.SC.SYS`
- `ERRBAR`
- `CCTL.IVALL`

and profiles as:

- `1284` instructions
- `38` regs/thread
- `4096 B` static shared
- `cycles ~12042.67`
- `long_scoreboard ~42.45%`
- `membar ~25.24%`
- `short_scoreboard ~8.03%`
- `barrier ~1.16%`

Compared with the non-uniform divergent SYS-store bridge, the uniform helper
front-end softens long-scoreboard pressure a bit but introduces a much larger
short-scoreboard component.

The direct `-dlcm=cg` comparison on that same fully fused branch under
`combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_172203`
is mildly negative overall: `cycles ~12170.44` (`+1.06%`) and
`lts__t_sector_hit_rate.pct ~67.50%` (`-2.34` points), even though
`membar` falls to about `22.69%`. So this heavier uniform+divergent store
body still does not gain a meaningful runtime win from `-dlcm=cg`.

The newer deeper fully fused store branch under
`combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_depth_safe_tranche_20260322_184634`
pushes that family further toward long-scoreboard dominance:
`cycles ~14812.33`, `long_scoreboard ~53.64%`, `membar ~17.37%`.

The matching deeper non-store branch under
`combo_uniform_divergent_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_185002`
then closes the control point we were missing:
`cycles ~13264.42`, `long_scoreboard ~49.96%`, `membar ~19.66%`.
So removing direct SYS load/store helps, but it does not collapse the branch
back into a light dependency-only regime.

Its direct `-dlcm=cg` control under
`combo_uniform_divergent_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_185120`
barely moves the runtime shape:
`cycles ~13224.93`, `long_scoreboard ~50.29%`, `membar ~19.05%`.
That strengthens the same high-level rule again: cache-policy mutation is not
the primary driver once this fused SYS64 body exists.

After folding those new branches back into a broader explorer refresh under
[`auto_explorer_20260322_190600`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_20260322_190600)
and
[`auto_explorer_queue_20260322_190600`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/auto_explorer_queue_20260322_190600),
the runtime queue is now exhausted. The explorer no longer sees a genuinely
unseen runtime-safe branch in the current registry; only the symbolic
`P2R.B1/B2/B3` boundary remains.

A fresh symbolic rerun under
[`p2r_symbolic_refresh_20260322_190301`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_symbolic_refresh_20260322_190301)
then tightened that remaining gap again. Both refreshed lanes,
plain `-O3` and `--maxrregcount=32`, still re-confirm only:

- `P2R R0, PR, R0, 0x7f`

and still flatten the literal `B1/B2/B3` carrier shapes through
`ISETP + SEL + LOP3.LUT` glue instead of surfacing `P2R.B1/B2/B3`.
The refreshed `-O3` SASS is byte-for-byte identical to the earlier
`p2r_b1_split_seed_20260321_125300` O3 bundle, which makes this a rigid
symbolic boundary rather than a flaky one.

A wider symbolic matrix under
[`p2r_symbolic_matrix_20260322_194108`](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_symbolic_matrix_20260322_194108)
then ranked the remaining local shapes against the cuDNN-mined `P2R.B*`
windows using
[`score_p2r_symbolic_boundary.py`](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/score_p2r_symbolic_boundary.py).
That ranking is stable across both `-O3` and `--maxrregcount=32`:

- best current `B1` approximation:
  `probe_p2r_b1_samecarrier_r7style_exact` (`jaccard_vs_ref = 0.258065`)
- second-best `B1` approximation:
  `probe_p2r_b1_dualpack_transition_exact` (`0.225806`)
- third-best `B1` approximation:
  `probe_p2r_b1_split_seed_exact` (`0.20`)
- fourth-best `B1` approximation:
  `probe_p2r_b1_samecarrier_late4_exact` (`0.193548`)
- fifth-best `B1` approximation:
  `probe_p2r_b1_secondbank_halfword_exact` (`0.166667`)
- `B2` approximations:
  tied at `0.16`
- best `B3` approximation:
  `probe_p2r_b3_split_seed_exact` (`0.16`)
- weakest current branch:
  `probe_p2r_b3_literal_cudnn_exact` (`0.115385`, and still the only one in
  this set to pick up `PRMT`)

So the residual symbolic frontier is now ordered as well as bounded:
the newer same-carrier `B1` retries are closer than the older split-seed
branch, `B1` still dominates the symbolic priority list, and the runtime-safe
frontier is exhausted. None of these tighter retries surfaces `P2R.B1/B2/B3`,
so the remaining gap is now both narrow and rigid.

The nibble-sized `0xf` variants add one more useful constraint:

- `probe_p2r_b2_nibble_exact` and `probe_p2r_b3_nibble_exact` now directly
  reproduce plain `P2R ... 0xf`
- both still miss byte-qualified `P2R.B2/B3`
- both pick up `PRMT`

So the last frontier is no longer "can we locally pack a small predicate
nibble?" We can. The last frontier is specifically the byte-qualified `P2R.B*`
selection itself.

The final whole-register masked-rewrite variants add one more negative
constraint:

- `probe_p2r_b1_regmask_transition_exact` ties the older `B1` nibble-
  transition path at `jaccard_vs_ref = 0.20`
- `probe_p2r_b2_regmask_transition_exact` ties the best `B2` paths at `0.16`
- `probe_p2r_b3_regmask_transition_exact` stays weak at `0.115385`
- all three still lower to plain `P2R ... 0xf` plus `LOP3`, and `B3` still
  picks up `PRMT`

So the last frontier is not a missed byte-store vs masked-rewrite carrier
style either. It is specifically byte-qualified `P2R.B1/B2/B3` form
selection.

The final staged same-carrier tripack adds one more useful RCA constraint:

- `probe_p2r_b2_tripack_prefix_exact` improves the local `B2` neighborhood to
  `jaccard_vs_ref = 0.192308`
- `probe_p2r_b3_tripack_prefix_exact` reaches `0.142857`
- both still lower to plain `P2R ... 0xf`
- `B3` still picks up `PRMT`

So even when prior higher-byte packs are already alive in the same carrier,
the local source-space compiler path still prefers plain `P2R` plus GPR glue
instead of byte-qualified `P2R.B*`.

That rescope changes what the explorer should consider "new":

- carrier lifetime is no longer a primary search axis
- byte-field writes vs masked GPR rewrites are no longer a primary axis
- mask width is no longer a primary axis
- the remaining primary symbolic axis is predicate-source kind, especially
  whether a bank is fed by `LOP3.LUT P*` / `PLOP3.LUT` rather than a mostly
  `ISETP`-driven predicate forest

So the next symbolic tranche should rank `PLOP3`-fed carrier proposals above
further same-carrier or regmask perturbations of the existing `ISETP`-heavy
family.

That tranche is now complete:
- `p2r_plop3_source_20260322_202900`
- `p2r_plop3_samecarrier_20260322_202951`
- `p2r_plop3_selpack_20260322_203047`

The result is stronger than another generic miss. Predicate-source kind does
change the emitted O3 neighborhood: these probes reproduce dense
`LOP3.LUT P*` and `PLOP3.LUT`. But the compiler still does not select
`P2R.B1/B2/B3`. In the surviving tripack kernel it keeps plain
`P2R ..., RZ, 0x1`; in the fused same-carrier variants it drops `P2R`
entirely and rebuilds the bytes with `SEL` plus `LOP3`. So the symbolic
frontier is no longer "find the right source shape". It is now "the remaining
byte-qualified form selection is probably outside ordinary CUDA C++ source
control on this toolchain."

## How to run it

```sh
python src/sass_re/scripts/auto_explorer.py \
  --outdir src/sass_re/results/runs/auto_explorer_manual_$(date +%Y%m%d_%H%M%S)
```

Outputs:

- `observed_runs.csv`
- `proposals.csv`
- `stack.json`
- `summary.txt`

## Recommended next implementation layers

1. Keep the current stdlib + sklearn + optuna core.
2. Add automatic runner-script selection for safe runtime branches.
3. Add experiment lineage tracking for proposed -> executed -> harvested runs.
4. Add a second-stage symbolic frontier policy for the remaining
   `P2R.B1/B2/B3` boundary.
5. Only then consider ONNX or a tiny MLP policy model if the proposal space
   becomes much larger.
