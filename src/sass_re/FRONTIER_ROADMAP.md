# SM89 Frontier Roadmap

This document scopes the highest-yield remaining work for the Ada SM89 SASS
toolkit after the manifest-backed recursive refreshes, the direct confirm
tranches, and the full-corpus 6x4 flag sweep.

It separates three different goals that should not be conflated:

1. Raw mnemonic frontier expansion
2. Runtime/performance characterization
3. Operational runner coverage

## Current frontier

Stable local facts:

- Canonical optimized frontier: `379` raw mnemonics
- Strongest discovery-lane frontier: `382` under `--maxrregcount=32`
- Strongest semantic flag lane: `--restrict` (`381`)
- Strongest load-policy lane: `-Xptxas -dlcm=cg`
- Remaining unreproduced direct-local cluster:
  - `P2R.B1`
  - `P2R.B2`
  - `P2R.B3`
- Already directly observed locally but adjacent to the same frontier:
  - `R2P` via the transcendental compile-profile path
  - `USHF.L.U64.HI` via `predicate_uniform_frontier_20260321_024500`
  - `ULOP3.LUT` in the uniform-path corpus
  - `P2R Rn, PR, Rn, 0x7f` via `p2r_two_stage_bank_20260321_110000`

Recently unblocked generic-runner coverage:

- `probe_atomic_throughput.cu`
- `probe_l1_l2_dram_boundary.cu`
- `probe_nanosleep_scheduling.cu`

Still unsafe for the generic runner:

- `probe_uniform_ushf_u64_hi_final.cu`
- `probe_optix_rt_core.cu`

Recently converted to dedicated-runner coverage:

- `probe_barrier_arrive_wait.cu`
- `probe_barrier_coop_groups_sync.cu`
- `probe_cooperative_launch.cu`
- `probe_tiling_hierarchical.cu`
- `barrier_sync2/probe_depbar_explicit.cu`

## Priority ranking

### Rank 1: Load / cache-policy combo frontier

This is now the highest-yield direct-local frontier.

Target family:

- `LD*`
- `LDG*`
- `LDGSTS*`
- `LDGDEPBAR`
- `DEPBAR.*`
- nearby uniform helpers such as `ULDC*`, `ULOP3.LUT`, and possibly `UISETP.*`

Why this is now the best frontier:

- It keeps producing direct local "wombo combo" wins in current source-space
  probes.
- The local corpus now has multiple emitted kernels where
  `LDG(.STRONG.GPU) + LDGSTS(.ZFILL) + LDGDEPBAR + DEPBAR.LE`
  coexist in one function.
- The widened combo probes now show that the same family can also carry
  `MATCH.ANY`, `REDUX.MIN.S32`, `REDUX.MAX.S32`, `REDUX.SUM(.S32)`,
  `VOTE.ALL`, `VOTE.ANY`, `VOTEU.ANY`, `POPC`, `UFLO.U32`,
  `ATOMG.E.ADD.STRONG.GPU`, `RED.E.MIN/MAX.S32.STRONG.GPU`,
  `ATOMG.E.MIN/MAX/AND/OR/XOR/EXCH/CAS.STRONG.GPU`,
  `ATOMG.E.EXCH.STRONG.SYS`, `ATOMG.E.CAS.STRONG.SYS`,
  `ATOMG.E.ADD.F32.FTZ.RN.STRONG.SYS`,
  `BAR.RED.POPC/AND/OR.DEFER_BLOCKING`, `B2R.RESULT`,
  `RED.E.MIN/MAX.S32.STRONG.SYS`, `RED.E.ADD.STRONG.SYS`, and
  `RED.E.ADD.F32.FTZ.RN.STRONG.SYS`,
  `LDG.E.64(.STRONG.GPU)`, `RED.E.ADD.64.STRONG.SYS`, and
  `ATOMG.E.CAS.64.STRONG.GPU`, `ATOMG.E.EXCH.64.STRONG.GPU`.
- A newer divergence/reconvergence combo run also shows that the same broad
  neighborhood can widen into `WARPSYNC`, `WARPSYNC.EXCLUSIVE`, `BSSY`,
  `BSYNC`, `CALL.ABS.NOINC`, and `RET.ABS.NODEC`, but currently only in the
  `-G` lane.
- The latest combo-only chain-mining pass also says the same thing from a
  different angle: the dominant anchor windows are now all async/cache
  variants, not predicate-byte outliers. The remaining frontier is therefore
  about sub-variant selection inside this family, not about discovering an
  absent neighborhood.
- The remaining open sub-question there is not whether the neighborhood exists,
  but whether a stricter uniform-only source shape can pull `UISETP.*` into
  that same chain.

Falsifiable hypotheses:

1. Additional `LDG/LDGSTS` scope-policy spellings can be combined with the
   async-depbar chain without losing the neighborhood.
2. `UISETP.*` in this frontier requires the compare operands to remain in
   uniform registers all the way through scheduling, not merely to be
   warp-uniform in source semantics.
3. The best next novelty wins are therefore mixed cache-policy / uniform-domain
   combos rather than more generic predicate-bank pressure.
4. Even a stricter uniform-first async/cache hybrid can still collapse back to
   `ISETP.*`; current evidence says the local compiler rewrites the compare
   chain before the `LDGSTS/LDGDEPBAR/DEPBAR` half unless the whole predicate
   path remains in the pure uniform corpus.
5. The next most likely direct-local combo wins are additional system-scope
   `RED.E.*` and scope-policy mixes rather than wider `ATOMG` coverage, because
   the block-red plus system-`RED` hybrid now lands cleanly in one kernel.
6. Even after adding `ULDC/UIADD3/ULOP3/USHF` back into the same
   system-`RED` async/cache kernel, the compare side still does not surface
   `UISETP.*`. That makes `UISETP` look like a stricter scheduling/form-
   selection issue rather than a missing neighborhood.
7. A more literal `stage_mask/tail_mask` control transplant from the known
   local `UISETP`-producing HMMA-toggle probe still collapses to ordinary
   `ISETP.*` once the body becomes async/cache + system-`RED`. So the next
   `UISETP` attempt should avoid normal C++ bool materialization and stay even
   closer to the exact UP/UR control skeleton.
8. The 64-bit scope-mix pivot confirms that widening the async/cache family
   with 64-bit load-policy and 64-bit atomic/reduction forms is higher-yield
   than continuing to brute-force `UISETP` inside mixed bodies.
9. The block-red plus 64-bit system-`RED` follow-up further strengthens that
   ranking: the next likely wins are deeper async/cache scope-mix adjacencies,
   not mixed-body `UISETP`.
10. The 64-bit system-atomic follow-up under
    `combo_atomg64sys_cache_wombo_20260321_153200` strengthens that ranking
    again: the same local family now reaches
    `ATOMG.E.CAS.64.STRONG.SYS`, `ATOMG.E.EXCH.64.STRONG.SYS`,
    `MEMBAR.SC.SYS`, `ERRBAR`, and `CCTL.IVALL` while preserving the
    established `LDG.E.64(.STRONG.GPU) -> LDGSTS -> LDGDEPBAR -> DEPBAR.LE`
    backbone. The most promising next branch is therefore deeper system-side
    scope/control widening, not another broad `UISETP` attempt.
11. The 64-bit system load/store follow-up under
    `combo_store64sys_cache_wombo_20260321_154200` confirms that prediction:
    the same local branch now reaches `LDG.E.64.STRONG.SYS`,
    `STG.E.64.STRONG.SYS`, `MEMBAR.SC.SYS`, `ERRBAR`, and `CCTL.IVALL`
    while preserving the exact same async/cache anchor. That re-ranks the
    next likely wins again toward wider system-side load/store/control mixes.
12. The 64-bit system op-matrix follow-up under
    `combo_atomg64sys_ops_cache_wombo_20260321_155400` strengthens that
    ranking again by landing, in one direct-local kernel:
    `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
    on top of the same async/cache anchor and the same
    `MEMBAR.SC.SYS` / `ERRBAR` / `CCTL.IVALL` tail. The highest-yield branch
    is now clearly richer system-side adjacency on top of this widened block.
13. The block-red plus 64-bit system-op-matrix follow-up under
    `combo_blockred_atomg64sys_ops_cache_wombo_20260321_160900` strengthens
    that ranking again: `BAR.RED.*` and `B2R.RESULT` survive alongside the
    dense 64-bit `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.STRONG.SYS` block on top of
    the same async/cache anchor. The next likely wins are nearby vote/match/
    warp helpers and system-scope load/store reuse inside this same body.
14. The fused warp-side follow-up under
    `combo_blockred_warp_atomg64sys_ops_cache_wombo_20260321_162300`
    confirms that prediction: `MATCH.ANY`, `REDUX.MIN/MAX/SUM(.S32)`,
    `VOTE.ALL`, and `VOTE.ANY` all survive alongside the same block-red and
    dense 64-bit system-ATOMG/control block. The active frontier is now a
    broader fused family, and the next likely question is whether a
    reconvergence-shaped variant can add `WARPSYNC` without breaking it.
15. The reconvergence-shaped follow-up under
    `combo_divergent_blockred_warp_atomg64sys_ops_cache_wombo_20260321_163500`
    refines that answer. Optimized code now admits `BSSY` and `BSYNC`
    alongside the fused family, while `WARPSYNC` and `WARPSYNC.EXCLUSIVE`
    remain debug-lane weighted on the same source shape. The next likely
    branch is a narrower optimized `WARPSYNC` chase if desired, but the
    highest-yield general frontier remains richer fused-family adjacencies.
16. The narrower optimized `WARPSYNC` chase under
    `combo_warpsync_fused_narrow_20260321_165100` tightens that boundary:
    even the least-disruptive full-mask and ballot-mask `__syncwarp` variants
    still keep optimized `BSSY` / `BSYNC` instead of selecting raw
    `WARPSYNC` in the fused family. So `WARPSYNC` should currently be treated
    as debug-lane weighted for this family unless a new, more literal
    optimized source shape emerges.
17. The store-side fused follow-up under
    `combo_blockred_warp_atomg64sys_ops_store_cache_wombo_20260321_170300`
    widens the same symbolic family again by adding
    `LDG.E.64.STRONG.SYS` and `STG.E.64.STRONG.SYS` on top of the same
    `MATCH/VOTE/REDUX + BAR.RED + dense 64-bit ATOMG.E.*.STRONG.SYS`
    body. But the first simple runtime runners for this denser SYS branch hit
    a `misaligned address` boundary during warmup, so this kernel is now a
    strong symbolic frontier and a runtime boundary at the same time.
18. A runtime-safe surrogate under
    `combo_warp_atomic_cache_profile_safe_tranche_20260322_000230`
    now provides the first trustworthy `ncu` anchor for the combo family
    without changing its core emitted neighborhood. The executable SASS still
    keeps `LDGSTS`, `LDGDEPBAR`, `DEPBAR.LE`, `MATCH.ANY`,
    `REDUX.MIN/MAX/SUM(.S32)`, `VOTE.ALL`, `VOTE.ANY`, `VOTEU.ANY`,
    `POPC`, `UFLO.U32`, and both `RED.E.ADD` forms.
19. That same profile-safe tranche also clarifies the performance shape of the
    family: it is primarily long-scoreboard limited rather than barrier- or
    membar-limited. Current measured stall split is roughly:
    `long_scoreboard 32.5%`, `short_scoreboard 3.8%`, `wait 4.9%`,
    `barrier 0%`, `membar 0%`, with only about `2.2%` DRAM throughput and a
    median L2 hit rate around `75.7%`.
20. That pushes the next highest-yield runtime/performance question away from
    barriers and toward dependency depth, scoreboard pressure, and cache-hit
    modulation inside the proven `LDGSTS/LDGDEPBAR/DEPBAR + warp/redux +
    RED/ATOM` family.
21. The direct `-dlcm=cg` comparison on that same runtime-safe surrogate under
    `combo_warp_atomic_cache_profile_safe_tranche_dlcm_cg_20260322_001200`
    strengthens that reading further: the load spellings flip to
    `LDG.E.U8/U16.STRONG.GPU`, but cycles, throughput, and the stall split stay
    essentially unchanged. That is strong evidence that this branch is more
    dependency-depth limited than cache-policy limited.
22. The 4-way safe-anchor matrix under
    `combo_family_safe_anchor_batch_20260322_001544` sharpens that further:
    increasing dependency depth on the smaller safe family raises instruction
    count, register count, shared-memory footprint, short-scoreboard stall,
    and wait stall, but does not introduce barrier or membar stalls. So the
    smaller family remains a clean dependency-depth/scoreboard study case.
23. The runtime-safe 64-bit SYS surrogate under
    `combo_blockred_warp_atomg64sys_ops_profile_safe_tranche_20260322_002817`
    closes the next major execution gap. It preserves the dense executable
    family with `BAR.RED.*`, `B2R.RESULT`, `MATCH`, `REDUX`, `VOTE`,
    `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`,
    `MEMBAR.SC.SYS`, `ERRBAR`, `CCTL.IVALL`, and `STG.E.64`.
24. That same runtime-safe 64-bit SYS surrogate also changes the performance
    regime qualitatively: long-scoreboard rises to about `53.4%` and membar
    becomes a major stall source at about `24.8%`. That means the denser
    system-scope family is no longer just a larger async/cache combo; it is a
    distinct memory-barrier plus dependency-latency regime.
25. This re-ranks the runtime frontier again:
    - smaller safe family: best for dependency-depth / scoreboard studies
    - 64-bit SYS safe family: best for memory-barrier and system-scope latency
      studies
    - dense store-side symbolic family: still useful as an emitted-SASS
      frontier, but no longer the only path to studying the system-scope body
26. The `-dlcm=cg` comparison on that 64-bit SYS-safe family under
    `combo_blockred_warp_atomg64sys_ops_profile_safe_tranche_dlcm_cg_20260322_003600`
    confirms that the heavier branch follows the same high-level rule as the
    smaller family: forcing `STRONG.GPU` load policy changes the emitted load
    spelling, but does not materially change the measured regime. The family
    remains dominated by long-scoreboard and membar pressure.
27. A deeper 64-bit SYS-safe follow-up under
    `combo_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_005633`
    strengthens that runtime map. The same fused family survives with a
    second round of `ATOMG.E.*.64.STRONG.SYS`, and the measured stall mix
    shifts from about `53.4% long_scoreboard / 24.8% membar` to about
    `45.9% long_scoreboard / 26.7% membar`, while short-scoreboard and wait
    also rise. So deeper SYS-side structure amplifies membar and secondary
    latency terms, but long-scoreboard remains the single largest stall class.
28. A runtime-safe store-side SYS surrogate under
    `combo_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_005938`
    closes the old symbolic/runtime split for the denser store-side family.
    It keeps direct `LDG.E.64.STRONG.SYS` and `STG.E.64.STRONG.SYS` live in
    executable code on top of the same block-red, warp, and dense 64-bit
    `ATOMG.E.*.STRONG.SYS` body.
29. The first `ncu` profile of that store-side safe surrogate shows it lives
    in essentially the same heavy regime as the deeper 64-bit SYS-safe
    branch:
    `long_scoreboard ~46.2%`, `membar ~25.7%`, `short_scoreboard ~1.7%`,
    `wait ~6.2%`, with `828` instructions, `40` registers/thread, and
    `4096 B` static shared memory.
30. The direct `-dlcm=cg` comparison on that store-side safe surrogate under
    `combo_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_010500`
    confirms the same general rule for the whole SYS-side branch:
    load spellings and L2 hit rate improve, but cycles and the stall mix stay
    nearly unchanged. So the now-executable store-side family is also
31. The deeper fully fused uniform + divergent + block-red + SYS64 + direct
    SYS store branch under
    `combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_depth_safe_tranche_20260322_184634`
    rebalances the regime again: it pushes long-scoreboard up to about
    `53.64%` while reducing `membar` to about `17.37%`. So deeper direct
    SYS-store fusion is a strong long-scoreboard stress lever.
32. The matching deeper non-store branch under
    `combo_uniform_divergent_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_185002`
    closes the missing comparison. It lowers cycles to about `13264.42` and
    trims long-scoreboard to about `49.96%`, but `membar` still stays near
    `19.66%`. So direct SYS store is not the sole source of the membar term;
    the broader SYS64 fused body still carries it.
33. The direct `-dlcm=cg` comparison on that new non-store depth branch under
    `combo_uniform_divergent_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_185120`
    shows only a tiny cycle shift and a small `membar` reduction while
    long-scoreboard stays near `50%`. This strengthens the same policy rule
    across another branch: `-dlcm=cg` is still a minor refinement lever, not
    a regime-changing one.
34. A wider symbolic matrix under
    `p2r_symbolic_matrix_20260322_194108` now orders the residual
    `P2R.B1/B2/B3` frontier more sharply by closeness to the cuDNN-mined
    windows. The current best local approximation is now
    `probe_p2r_b1_samecarrier_r7style_exact`, followed by
    `probe_p2r_b1_dualpack_transition_exact`, then the older
    `probe_p2r_b1_split_seed_exact`. The `B2` and `B3` branches remain
    flatter and clustered below that.
35. That same matrix also confirms that no current local variant escapes the
    flattened `ISETP + SEL + LOP3.LUT` path, and no current register-pressure
    control changes the ordering. So the remaining frontier is now both
    narrow and ordered:
    first `B1`, then `B2/B3`, with runtime-safe expansion presently
    exhausted.
36. The same refreshed matrix also adds a new nibble-sized constraint:
    `probe_p2r_b2_nibble_exact` and `probe_p2r_b3_nibble_exact` directly
    reproduce plain `P2R ... 0xf` plus `PRMT`, but still do not select
    `P2R.B2/B3`. That means the last unresolved gap is no longer generic
    small-mask predicate packing; it is byte-qualified `P2R.B*` form
    selection itself.
37. A final regmask-transition retry then closes the last obvious alternative
    lowering path. The whole-register masked rewrites
    `probe_p2r_b1_regmask_transition_exact`,
    `probe_p2r_b2_regmask_transition_exact`, and
    `probe_p2r_b3_regmask_transition_exact` still lower to plain
    `P2R ... 0xf` plus `LOP3`, with `B3` still picking up `PRMT`.
    So the remaining symbolic frontier is not a missed carrier-update style;
    it is byte-qualified `P2R.B*` form selection itself.
38. A final staged same-carrier tripack then closes the last obvious
    higher-byte-liveness question. `probe_p2r_b2_tripack_prefix_exact` and
    `probe_p2r_b3_tripack_prefix_exact` keep successive `0xf` packs alive in
    one carrier in the same order as the cuDNN `R231` pocket. `B2` improves
    to `jaccard_vs_ref = 0.192308`, but both tripack variants still lower to
    plain `P2R ... 0xf`, and `B3` still picks up `PRMT`.
39. Root-cause reading: the missing transition is not mask width, not
    same-carrier lifetime, not byte-store vs masked-register rewrite, and not
    higher-byte prefix state. The remaining gap appears to be compiler form
    selection between plain `P2R` plus GPR glue and byte-qualified `P2R.B*`
    on a live predicate-bank path.
40. Rescope after RCA: stop spending frontier budget on more carrier-style
    retries that only vary mask width, byte write form, or packed-prefix
    lifetime. Those axes are now strip-mined.
41. The one remaining meaningful axis is predicate-source kind. The
    cuDNN-mined `P2R.B*` pockets are embedded in predicate-logic neighborhoods
    dominated by `LOP3.LUT P*` / `PLOP3.LUT`, while the local O3 retries that
    get closest still mostly build the bank from `ISETP` and then materialize
    through plain `P2R` plus GPR glue.
42. Forward plan: build one last family of O3-targeted `PLOP3`-fed carrier
    probes, score them against the cuDNN `R195` and `R231` windows, and only
    continue if they improve the byte-qualified boundary beyond the current
    `B1` / `B2` tripack approximations.
43. Final `PLOP3`-fed strip-mine result:
    `p2r_plop3_source_20260322_202900`,
    `p2r_plop3_samecarrier_20260322_202951`, and
    `p2r_plop3_selpack_20260322_203047` all confirm the same boundary. O3 can
    reproduce dense `LOP3.LUT P*` / `PLOP3.LUT` predicate neighborhoods, but
    that still does not trigger byte-qualified `P2R.B1/B2/B3`.
44. Strongest RCA from source-space:
    when the predicate graph is simple enough, local O3 may still choose plain
    `P2R` (`0x7f` or `0x1`) plus GPR glue; when the predicate graph is made
    more `PLOP3`-rich, the compiler often drops `P2R` entirely and rebuilds
    the bytes with `SEL` and `LOP3`.
45. Working conclusion:
    the remaining `P2R.B*` family is likely compiler-internal, library-only,
    or dependent on a lower-level IR/pattern that ordinary CUDA C++ source
    shaping does not expose on this local toolchain.
31. The normalized family matrix under
    `combo_family_ncu_batch_20260322_022222`
    now makes the runtime frontier easier to reason about as a whole:
    - small safe family: dependency-depth / scoreboard study case
    - 64-bit SYS-safe family: long-scoreboard + membar regime
    - store-side SYS-safe family: same heavy regime, but with direct SYS
      load/store now live in executable code
32. The same batch also sharpens the shallow/deep comparison inside the
    64-bit SYS-safe branch. Deepening the structure does not make membar
    overtake long-scoreboard; it raises membar, short-scoreboard, and wait,
    while long-scoreboard remains the single largest stall class.
33. A runtime-safe uniform-helper/system-`RED` follow-up under
    `combo_uniform_redsys_async_profile_safe_tranche_20260322_133653`
    closes the next missing runtime branch for the combo family. It preserves
    `ULDC/UIADD3/ULOP3/USHF + LDGSTS/LDGDEPBAR/DEPBAR +
    RED.E.MIN/MAX/ADD(.F32).STRONG.SYS` in executable code.
34. That same uniform-helper/system-`RED` runtime branch profiles as a lighter
    dependency-latency family:
    `long_scoreboard ~29.3%`, `short_scoreboard ~2.9%`, `wait ~7.1%`,
    `barrier = 0%`, `membar = 0%`, with about `24` regs/thread and
    `1024 B` static shared memory. So it belongs closer to the smaller safe
    branch than to the heavy 64-bit SYS-safe/store-side SYS-safe branches.
35. A narrow 64-bit SYS atomic matrix surrogate under
    `combo_atomg64sys_ops_profile_safe_tranche_20260322_135833`
    now closes the next symbolic/runtime split without the full wider fused
    body. It preserves
    `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`
    plus `MEMBAR.SC.SYS`, `ERRBAR`, and `CCTL.IVALL` on the same
    `LDG.E.64 + LDGSTS + LDGDEPBAR + DEPBAR.LE` backbone.
36. That narrow SYS matrix profiles as the cleanest membar-dominated
    executable branch seen so far:
    `long_scoreboard ~23.8%`, `membar ~37.8%`, `wait ~5.8%`, with
    `32` regs/thread and `1024 B` static shared memory.
37. A divergent fused runtime-safe surrogate under
    `combo_divergent_blockred_warp_atomg64sys_ops_profile_safe_tranche_20260322_140111`
    now preserves optimized `BSSY` and `BSYNC` in executable code alongside
    the fused block-red, warp, and dense 64-bit SYS atomic family.
38. That divergent executable branch stays in the same broad heavy SYS-side
    regime, but with a distinct split:
    `barrier ~1.3%`, `long_scoreboard ~24.0%`, `membar ~33.7%`,
    `wait ~6.4%`.
39. A first Python auto-explorer report under
    `auto_explorer_20260322_141500` now ingests the combo-family `.sass`
    and `ncu` corpus through an explicit TOML search-space registry and a
    stdlib-first Python scorer.
40. The explorer's first ranking agrees with the hand-built frontier:
    the best next runtime-safe branches are
    `uniform_blockred_sys64_store`,
    `uniform_blockred_sys64_depth`, and
    `uniform_blockred_sys64_store_dlcm_cg`,
    while the residual symbolic-only boundary remains `P2R.B1/B2/B3`.
41. The useful thing borrowed from `open_gororoba` here is the explicit
    registry / lineage pattern, not the Cayley-Dickson algebra itself.
    The current frontier is still sparse and discrete enough that a
    registry-driven classical explorer is more justified than a learned
    hypercomplex embedding.
42. The current installed Python stack on this workstation already supports
    a serious first auto-explorer:
    `numpy`, `pandas`, `networkx`, `scikit-learn`, `optuna`, `onnx`,
    `onnxruntime`, `torch`, `typer`, and `pydantic`.
43. A queue artifact under `auto_explorer_queue_20260322_143000` now turns
    the proposal table into a compact execution order while reusing the same
    explicit TOML registry rather than inventing a separate planner.
44. The first executed explorer pick under
    `combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_143100`
    validates the explorer's highest-ranked runtime continuation.
45. That executed branch preserves, in one executable kernel:
    `ULDC(.64)`, `UIADD3`, `ULOP3.LUT`, `USHF.L.U32`, `USHF.L.U64.HI`,
    `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)`,
    `LDGDEPBAR`, `DEPBAR.LE`,
    `BAR.RED.*`, `B2R.RESULT`,
    `MATCH.ANY`, `REDUX.*`, `VOTE.ALL`, `VOTE.ANY`,
    `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS`,
    `LDG.E.64.STRONG.SYS`, `STG.E.64.STRONG.SYS`,
    `MEMBAR.SC.SYS`, `ERRBAR`, and `CCTL.IVALL`.
46. The executed branch also spontaneously picks up optimized `BSSY` and
    `BSYNC`, so the realized frontier is stronger than the original
    non-divergent proposal the explorer started from.
47. Its first `ncu` profile puts it in the heavy fused SYS-side regime:
    `1152` instructions, `38` regs/thread, `4096 B` static shared memory,
    `long_scoreboard ~47.4%`, `membar ~25.0%`, `short_scoreboard ~1.1%`,
    `barrier ~0.9%`, `wait ~6.0%`.
48. That means the most productive next explorer continuations are now:
    - the `-dlcm=cg` variant of this same fused branch
    - the deeper fused uniform + block-red + SYS64 branch
    - the narrower `ATOMG`-only SYS64 policy comparison
    while the residual symbolic-only raw-SASS boundary still remains
    `P2R.B1/B2/B3`.
49. The direct `-dlcm=cg` follow-up under
    `combo_uniform_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_145200`
    shows that policy is a modest refinement lever on this fused branch:
    cycles improve by about `1.25%`, `long_scoreboard` drops by about
    `0.67` percentage points, and `membar` drops by about `1.97` points.
50. The deeper fused follow-up under
    `combo_uniform_blockred_warp_atomg64sys_ops_store_profile_depth_safe_tranche_20260322_145200`
    shows that extra structure mainly pushes the branch into a stronger
    long-scoreboard regime rather than improving the overall kernel:
    cycles rise about `14.77%`, `long_scoreboard` rises about `11.02`
    points, and `membar` falls about `5.16` points.
51. The refreshed explorer and queue under
    `auto_explorer_20260322_150000` and
    `auto_explorer_queue_20260322_150100`
    now treat the branch accordingly:
    - best runtime-safe continuations:
      `uniform_blockred_sys64_depth`,
      `uniform_blockred_sys64_store`,
      `uniform_blockred_sys64_store_dlcm_cg`,
      `narrow_atomg_sys64_depth`,
      `narrow_atomg_sys64_dlcm_cg`
    - residual symbolic-only raw-SASS boundary:
      `P2R.B1/B2/B3`
52. The auto-explorer now ingests both wide and long-form Nsight Compute CSV
    layouts. That matters because the newer bridge tranches were initially
    emitting valid `ncu` data in long form, but the explorer only knew the
    wide layout and therefore undercounted them.
53. A new runtime-safe uniform + divergent + SYS64 bridge under
    `combo_uniform_divergent_atomg64sys_profile_safe_tranche_20260322_170855`
    now closes the next execution gap without introducing block-red or SYS
    stores. It keeps `ULDC.64`, `UIADD3`, `ULOP3.LUT`, `USHF`, the
    `LDGSTS/LDGDEPBAR/DEPBAR` backbone, and a warp/divergence shape in one
    executable body. Its measured regime is
    `long_scoreboard ~20.56%`, `membar ~31.67%`, and
    `short_scoreboard ~10.76%`, making it a useful midpoint between the
    lighter uniform-helper family and the heavier SYS-store fused branch.
54. A new runtime-safe divergent + SYS64 store bridge under
    `combo_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_171218`
    closes the next major bridge on the heavy side. It keeps
    `BSSY/BSYNC`, `BAR.RED.*`, `B2R.RESULT`, `MATCH/REDUX/VOTE`,
    direct `LDG.E.64.STRONG.SYS` and `STG.E.64.STRONG.SYS`, the dense
    `ATOMG.E.*.64.STRONG.SYS` matrix, and the
    `MEMBAR.SC.SYS` / `ERRBAR` / `CCTL.IVALL` tail in one executable body.
55. That divergent SYS-store bridge also clarifies causality inside the fused
    family. Its measured regime,
    `long_scoreboard ~44.26%` and `membar ~25.15%`,
    is much closer to the heavy store-side fused family than to the lighter
    uniform-divergent midpoint. That strongly suggests direct SYS load/store,
    not divergence alone, is what pulls the branch back into the heavier
    long-scoreboard + membar profile.
56. The direct `-dlcm=cg` comparison for that same bridge under
    `combo_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_171344`
    sharpens the policy story again. It flips the leading load to
    `LDG.E.64.STRONG.GPU`, but cycles get slightly worse
    (`+1.99%`), L2 hit rate drops by about `9.39` points, and `membar`
    rises slightly. So on this divergent SYS-store bridge, `-dlcm=cg` is not
    a useful refinement lever.
57. A new runtime-safe uniform + block-red + SYS64 depth bridge under
    `combo_uniform_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_172135`
    now closes the next uniform-side gap without direct SYS store. It keeps
    `ULDC/UIADD3/ULOP3/USHF`, the `LDGSTS/LDGDEPBAR/DEPBAR` backbone,
    `BAR.RED.*`, `B2R.RESULT`, `MATCH/REDUX/VOTE`, and the dense
    `ATOMG.E.*.64.STRONG.SYS` matrix. Its measured profile is
    `cycles ~12529.48`, `long_scoreboard ~54.97%`, and `membar ~22.40%`,
    which means the deeper uniform+blockred SYS64 branch is now strongly
    long-scoreboard-driven even before direct SYS store is reintroduced.
58. A new runtime-safe uniform + divergent + block-red + SYS64 + direct SYS
    store bridge under
    `combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_172130`
    closes the next aggressive fused gap. It keeps the uniform helper front-
    end together with `BSSY/BSYNC`, `BAR.RED.*`, `B2R.RESULT`,
    `MATCH/REDUX/VOTE`, direct `LDG.E.64.STRONG.SYS` /
    `STG.E.64.STRONG.SYS`, and the dense `ATOMG.E.*.64.STRONG.SYS` matrix.
59. That new aggressive fused branch clarifies another causal split. Its
    measured profile,
    `long_scoreboard ~42.45%`, `membar ~25.24%`,
    `short_scoreboard ~8.03%`,
    shows that the uniform front-end trims long-scoreboard pressure compared
    with the non-uniform divergent SYS-store bridge, but introduces a much
    larger short-scoreboard term.
60. The direct `-dlcm=cg` comparison for that same fully fused branch under
    `combo_uniform_divergent_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_172203`
    is mildly negative overall:
    `cycles ~12170.44` (`+1.06%`),
    `lts__t_sector_hit_rate.pct ~67.50%` (`-2.34` points), while
    `membar` falls to about `22.69%`.
    So for this heavier uniform+divergent SYS-store body, `-dlcm=cg`
    lowers `membar` but still does not buy a net runtime win.
61. The refreshed explorer and queue under
    `auto_explorer_20260322_174400` and
    `auto_explorer_queue_20260322_174400`
    now fold in both new uniform+SYS64 runtime branches. The symbolic-only
    direct-local raw-SASS boundary still remains `P2R.B1/B2/B3`.
62. The lighter uniform+divergent SYS64 midpoint branch now also has a direct
    `-dlcm=cg` comparison under
    `combo_uniform_divergent_atomg64sys_profile_safe_tranche_dlcm_cg_20260322_173400`.
    There, `lts__t_sector_hit_rate.pct` improves to about `73.69%`, but
    cycles still worsen slightly to about `9701.17`.
    So the policy story is now consistent across both lighter and heavier
    runtime-safe branches: `-dlcm=cg` can change cache behavior without
    delivering a net runtime win.
63. The non-store uniform+blockred SYS64 depth branch also now has a direct
    `-dlcm=cg` comparison under
    `combo_uniform_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_dlcm_cg_20260322_174100`.
    There, cycles improve only marginally to about `12483.15`, while
    `lts__t_sector_hit_rate.pct` falls to about `71.25%` and `membar`
    rises to about `24.28%`.
    So even where policy is slightly favorable on cycles, it is still not a
    clean first-order lever on this fused family.

Planned probe tranche:

- `probe_combo_cache_policy_uniform_uisept.cu`
  - pure-uniform compare setup
  - cache-policy loads
  - async-depbar chain
- `probe_ldgsts_policy_scope_matrix.cu`
  - `.ZFILL`, `.BYPASS`, `.LTC128B`, scope-policy variants
- `probe_ldg_strong_subword_combo.cu`
  - scalar / subword strong-GPU loads in one kernel
- `probe_uniform_async_compare_chain.cu`
  - `ULDC/ULOP3/UIADD3/UISETP/USEL/USHF`
  - plus `cp.async` neighborhood

Success criteria:

- New direct-local combo chains in the
  `LDG(.STRONG.GPU) + LDGSTS + LDGDEPBAR + DEPBAR` family
- or wider coexistence of warp/atomic neighbors inside that same family
- or a first direct-local `UISETP.*` inside that same async/cache half

### Rank 2: Predicate / uniform frontier

Highest expected raw mnemonic yield per engineering hour.

Target family:

- `P2R.B*`
- byte-qualified `R2P` reload shapes
- wider `UISETP.*`
- `USHF.L.U64.HI`

Why this is the best frontier:

- It is the only remaining cluster that repeatedly appears in cuDNN-mined or
  strongly adjacent local codegen neighborhoods but still resists direct local
  reproduction.
- It is tightly coupled to the already-proven frontier movers:
  `--maxrregcount=32`, `UISETP.*`, `PLOP3.LUT`, `ULEA*`, `ULDC*`, and
  software-pipelined tensor mainloops.
- It is more likely to reveal genuinely new raw spellings than the already
  exhausted video `V*` family.

Falsifiable hypotheses:

1. `P2R.B1/B2/B3` requires longer-lived packed predicate-byte lifetimes than
   the current direct probes preserve.
2. The current local compiler can reproduce the broader same-carrier full-mask
   shape `P2R Rn, PR, Rn, 0x7f`, but still lowers byte-one carrier rewrites to
   `ISETP` + `SEL` + `LOP3.LUT` glue rather than `P2R.B1/B2/B3`.
3. The remaining `P2R.B*` family may therefore be compiler-internal or
   library-only unless the exact cuDNN live-carrier neighborhood is matched
   more literally than current source-space probes allow.
4. Corpus-wide chain mining should show whether the cuDNN "wombo combos" are
   actually absent locally or merely redistributed across different probes.
   The first comparison now says they are already present locally as
   neighborhoods; the remaining gap is byte-qualified form selection.

Planned probe tranche:

- `probe_predicate_bank_state_machine.cu`
  - long-lived predicate banks
  - multiple save/reload points
  - cross-iteration predicate packing
- `probe_r2p_bank_rehydrate_pipeline.cu`
  - packed integer mask -> byte-bank predicate rehydration
  - staged use after reload
- `probe_uniform_predicate_truth_table.cu`
  - warp-uniform predicate LUTs
  - explicit table-driven uniform predicate logic
- `probe_uniform_u64_carry_chain.cu`
  - multiple dependent uniform 64-bit carry stages
  - address-generation and non-address-generation variants
- `probe_cutlass_mainloop_predicate_banks.cu`
  - CUTLASS-like software-pipelined HMMA + `cp.async`
  - explicit stage predicates
  - long-lived banked masks

Required infrastructure:

- one custom runner for the CUTLASS-like mainloop probe if the generic launcher
  cannot preserve the intended stage geometry
- one compile lane that pairs `--maxrregcount=32` with the new predicate probes

Success criteria:

- Any direct local appearance of `P2R.B1/B2/B3`, a byte-qualified `R2P`
  reload, `UPLOP3.LUT`, or `USHF.L.U64.HI`
- or stronger negative evidence that these are library/compiler-internal forms
  not reproducible from ordinary local source shapes

### Rank 3: Residual direct-local `P2R.B*` frontier

This is now a tightly bounded residual gap, not the main engineering frontier.

Target family:

- `P2R.B1`
- `P2R.B2`
- `P2R.B3`

Why this is lower priority now:

- The boundary is now strongly evidenced by repeated direct-local failures plus
  corpus-wide rescans.
- Local raw `.sass` already contains `P2R Rn, PR, Rn, 0x7f` and many nearby
  neighborhoods.
- cuDNN-mined libraries still show `P2R.B1`, but current source-space probes
  do not flip local codegen into the byte-qualified forms.

Success criteria:

- Any first direct-local appearance of `P2R.B1`, `P2R.B2`, or `P2R.B3`

### Rank 4: Barrier / cooperative / tiling custom-runner conversion

This is partly a coverage task and partly a possible mnemonic frontier.

Target probes:

- `probe_optix_rt_core.cu`
- `probe_uniform_ushf_u64_hi_final.cu`

Why it matters:

- These probes already contain relevant SASS in disassembly
  (`BAR.ARV`, `BAR.SYNC`, `PLOP3.LUT`, `ULOP3.LUT`, `USEL`, `HMMA`,
  `LDGSTS`, `WARPSYNC`), but the generic runner is not safe for them.
- Converting them to dedicated runners may improve profiling coverage and may
  also surface additional dynamic behavior clues.

Falsifiable hypotheses:

1. `probe_optix_rt_core` requires a dedicated RT-core launch path rather than
   a plain CUDA runner.
2. `probe_uniform_ushf_u64_hi_final` remains intentionally synthetic enough to
   be unsafe for the generic runner even though its disassembly is still useful.

Planned runner tranche:

- optional `runners/optix_rt_core_runner.cu`

Completed tranche:

- `runners/barrier_arrive_wait_runner.cu`
- `runners/barrier_coop_groups_runner.cu`
- `runners/cooperative_launch_runner.cu`
- `runners/depbar_explicit_runner.cu`
- `runners/tiling_hierarchical_runner.cu`
- validation bundle:
  `results/runs/custom_runner_validation_20260321_012900`
- validation bundle:
  `results/runs/runner_tail_validation_20260321_014800`

Remaining success criteria:

- Convert the remaining `EXPECTED_SKIP` or intentionally unsafe runtime cases
  into either clean dedicated-runner `ncu` passes or explicit permanent
  disassembly-only classifications

### Rank 4: HMM / Unified Memory runtime frontier

This is a performance/behavior frontier, not primarily a raw mnemonic frontier.

Local system status already confirms:

- Driver branch: `595.45.04`
- CUDA version reported by `nvidia-smi`: `13.2`
- Kernel: `6.19.7-1-cachyos`
- Addressing mode: `HMM`
- Open kernel modules are installed locally

Implication:

- The CUDA-to-system-RAM sharing path is already enabled on this machine.
- Installing another package is unlikely to change the raw SM89 mnemonic
  frontier.

GreenBoost-specific state:

- `greenboost-dkms` is packaged locally under
  `~/Github/pkgbuilds/greenboost-dkms` and installed successfully.
- The local `nvcc` toolchain requires a fallback to `-std=c++20`; the SASS RE
  scripts now resolve that automatically.
- `runtime_greenboost_driver_tranche_ctxmodes_20260321_085750` shows that
  GreenBoost Path A still fails at `cuMemHostGetDevicePointer(...)=201` even
  when the current context already reports `ctx_has_map_host=1`.
- `runtime_hostreg_probe_20260321_085842` shows that raw
  `cuMemHostRegister + cuMemHostGetDevicePointer` succeeds outside the shim on
  the same host.
- `runtime_hostreg_symbol_probe_20260321_090753` shows why:
  the legacy unsuffixed `cuMemHostGetDevicePointer` symbol returns
  `CUDA_ERROR_INVALID_CONTEXT` on this stack, while
  `cuMemHostGetDevicePointer_v2` succeeds on the same allocation.
- `greenboost-dkms 2.5-3` now carries a local compatibility patch that
  prefers `_v2` host-registration symbols first.
- `runtime_greenboost_driver_tranche_v2pref_20260321_091139` and
  `runtime_greenboost_tranche_v2pref_20260321_091159` confirm that both Path A
  (`DMA_BUF`) and Path B (`HOSTREG`) now work locally.
- `runtime_greenboost_perf_tranche_20260321_094142` now shows that:
  - Path A and Path B are performance-similar on this host
  - both stay around `19-25 GiB/s` effective throughput for broad
    streaming-style or read-mostly kernels
  - sparse stride traffic is especially bad, around `1 GiB/s`
  - very high arithmetic intensity reduces the penalty to about `1.5x`
    relative to baseline VRAM
  - Path C (`UVM`) stays near baseline for the tested 256 MiB working set
- `runtime_greenboost_oversub_tranche_20260321_094432` now adds the first
  beyond-free-VRAM result:
  - requested Path A at `14 GiB` does not stay on DMA-BUF; the shim reports
    `GB_IOCTL_PIN_USER_PTR failed for 14336 MB: Invalid argument` and falls
    back to `HOSTREG`
  - Path A fallback and Path B remain slow but stable in the same rough band
  - Path C (`UVM`) shows a radically different oversubscription shape:
    cheap allocation, expensive first-touch, catastrophic full-range second
    touch, but excellent second-pass hot-window reuse after residency settles
- `runtime_greenboost_dmabuf_size_sweep_20260321_094708` now constrains the
  DMA-BUF eligibility envelope directly:
  - `4 GiB`: real `DMA_BUF`
  - `8 GiB` and above: `GB_IOCTL_PIN_USER_PTR ... Invalid argument`,
    fallback to `HOSTREG`
- `runtime_greenboost_dmabuf_size_sweep_20260321_104547` now tightens that:
  - `4.125 GiB` already fails
  - the local DMA-BUF eligibility cliff is therefore between `4.0 GiB` and
    `4.125 GiB`
- Installed source inspection in `/usr/src/greenboost-2.5/greenboost.c` now
  explains that cliff:
  - `GB_IOCTL_PIN_USER_PTR` rejects
    `req.size > (u64)virtual_vram_gb * (1ULL << 30)`
  - the observed boundary came from loading the module with
    `virtual_vram_gb=4`
  - a targeted rerun with `virtual_vram_gb=8` confirms that `8 GiB` can stay
    on real `DMA_BUF`

Falsifiable hypotheses:

1. The functional GreenBoost compatibility blocker on this host was legacy
   host-registration symbol resolution, not a generic CUDA host-map gap.
2. After the `_v2` fix, the next important question is performance:
   Path A and Path B should work functionally, but should remain much slower
   than VRAM-resident execution on bandwidth-heavy kernels.
3. Path A may still beat Path B on some access patterns because the DMA-BUF
   route gives the kernel module more control over page provisioning and T2/T3
   accounting, even when both resolve to system-RAM-backed CUDA pointers.
4. For working sets that remain below practical VRAM pressure, Path C may
   continue to look near-baseline even though its behavior should diverge once
   managed migration becomes dominant.
5. Large-allocation DMA-BUF eligibility may be constrained independently of
   ordinary host-registration success, causing Path A to fall back to Path B
   for some oversubscribed sizes.
6. On this machine, the earlier `4 GiB` / `4.125 GiB` cliff is explained by
   the current module configuration (`virtual_vram_gb=4`), not by a deeper
   CUDA or DMA-BUF limitation.
- The right next step is runtime characterization, not package hunting.

Latest measured local evidence:

- `src/sass_re/results/runs/runtime_hmm_tranche_20260321_020217`
- 64 MiB managed working set
- cold GPU access after host residency: `23.55 ms`
- explicit prefetch to GPU: `0.641 ms` (`36.74x`)
- host touch after GPU residency: `342.85 ms`
- prefetch back to CPU before host touch: `103.66 ms` (`3.31x`)
- `SetPreferredLocation + SetReadMostly + prefetch` on a write-heavy kernel:
  `5145.21 ms`, a strongly negative result on this workload

Falsifiable hypotheses:

1. HMM oversubscription changes latency and migration behavior, but does not
   create new core SASS mnemonic families.
2. `cudaMemPrefetchAsync` can materially reduce migration overhead relative to
   unmanaged on-demand HMM faults.
3. Some kernels cross a sharp performance cliff when their managed working set
   exceeds effective VRAM residency and begins migrating over HMM.
4. Advice choice is workload-dependent: the wrong advice can be catastrophically
   harmful on a write-heavy managed path.
5. L2 persistence and HMM migration controls interact: pinned hot windows may
   still help once the hot subset remains resident.

Current runtime tranche:

- `runners/runtime_hmm_features_runner.cu`
  - `cudaMallocManaged`
  - `cudaMemPrefetchAsync`
  - `cudaMemAdvise`
  - host-touch vs device-touch ordering
- `scripts/validate_runtime_hmm_tranche.sh`
  - timing
  - `ncu`

Next expansion:

- add an oversubscription sweep
- add `nsys` Unified Memory migration traces
- split read-mostly vs write-heavy kernels so advice effects are measured on
  the right access patterns

Metrics:

- launch overhead
- page-fault / migration timing
- achieved bandwidth
- active warps
- DRAM and L1TEX bytes
- if `nsys` is used, Unified Memory migration and page-fault events

Success criteria:

- Reproducible local evidence for when HMM helps, when it hurts, and how much
  prefetch/advice reduces the penalty

### Rank 4B: GreenBoost runtime frontier

This is adjacent to HMM, but it is not the same mechanism. GreenBoost is a
third-party kernel module plus CUDA shim that tries to make selected
`cudaMalloc`-style overflows look like device memory by routing them into
system-backed paths.

Local status:

- Upstream verified from the NVIDIA March 2026 forum release thread and the
  GitLab source tree
- Local package added:
  `~/Github/pkgbuilds/greenboost-dkms`
- Local install result:
  DKMS builds cleanly for both local kernels, the shim is installed at
  `/usr/lib/libgreenboost_cuda.so`, and `modprobe greenboost` creates
  `/dev/greenboost`

Latest measured local evidence:

- `src/sass_re/results/runs/runtime_greenboost_tranche_20260321_082925`
- `src/sass_re/results/runs/runtime_greenboost_driver_tranche_20260321_083427`
- baseline 512 MiB `cudaMalloc`:
  `alloc_ms=0.153111`, `first_kernel_ms=11.966464`
- forced Path A (`DMA-BUF + kernel module`):
  `alloc_ms=916.656588`, `resolved_path=DMA_BUF_FAILED`
- forced Path B (`HostReg`):
  `alloc_ms=728.332168`, `resolved_path=HOSTREG_TO_UVM`
- forced Path C (`UVM`):
  `alloc_ms=0.126451`, `resolved_path=UVM`

Working interpretation:

1. The functional compatibility blocker is solved locally; Path A and Path B
   now both resolve correctly.
2. Path A and Path B are not meaningfully distinct performance classes on the
   tested Ada desktop; both behave like DDR-backed PCIe tiers.
3. For bandwidth-heavy, read-mostly, and sparse-touch kernels, the DDR-backed
   tiers remain much slower than baseline VRAM residency.
4. For very high arithmetic-intensity kernels, the DDR-tier penalty shrinks to
   roughly `1.5x`, which makes GreenBoost more plausible for cold weights or
   compute-amortized phases than for hot streaming tensors or sparse KV-style
   access.
5. Path C (managed/UVM) is still the best local overflow path for the tested
   sub-VRAM-pressure working sets and hot-window reuse patterns.
6. Under real oversubscription, Path C can degrade catastrophically for
   full-range revisits, while the GreenBoost DDR-backed paths remain slower but
   more predictable.
7. The next GreenBoost-specific blocker is not symbol compatibility anymore;
   it is understanding the size or shape limits behind the DMA-BUF
   `GB_IOCTL_PIN_USER_PTR` rejection.

Next expansion:

- add larger-than-free-VRAM cases to force real migration pressure
- add a size sweep around the `GB_IOCTL_PIN_USER_PTR` failure threshold so the
  DMA-BUF eligibility envelope is refined rather than guessed
- bisect the `4 GiB` to `8 GiB` gap to find the first failing size and whether
  the limit is tied to hugepage geometry, module policy, or ioctl argument
  validation
- the `virtual_vram_gb x size` surface is now measured under
  `runtime_greenboost_policy_surface_20260321_112937`; next step is to add
  `nsys` migration traces and more access-pattern diversity on top of that
- the first `nsys` migration tranche is now captured under
  `runtime_greenboost_nsys_tranche_20260321_114548`; the newer
  `runtime_greenboost_nsys_tranche_20260321_115053` now adds the direct
  `DMA_BUF` vs `HOSTREG` comparison and shows that both DDR-backed paths are
  registration-dominated rather than migration-dominated
- the expanded access-pattern tranche under
  `runtime_greenboost_nsys_tranche_20260321_115747` now shows that fixed
  hot-window reuse favors `DMA_BUF`, while hopping-window pressure makes
  `DMA_BUF` and `HOSTREG` much closer in registration cost
- the first chain-mining comparison under
  `chain_mine_compare_20260321_121200` shows that the strongest cuDNN anchor
  windows already exist in the local corpus, so the next probe pressure should
  target byte-qualified form selection, not entirely new neighborhoods
- the corpus-wide boundary re-scan under `p2r_boundary_rescan_20260321_124500`
  confirms that local raw `.sass` already contains `P2R ... 0x7f` and
  `ULOP3.LUT`, but still no direct-local `P2R.B1/B2/B3`
- the final split-seed attempt under `p2r_b1_split_seed_20260321_125300`
  still re-confirms `P2R ... 0x7f` rather than `P2R.B1`, which is a strong
  stopping point for the current byte-qualified chase
- the next likely mnemonic-combo pivot under
  `chain_pivot_ldg_uisept_ulop3_20260321_130000` is the
  `ULOP3/UIADD3/ULDC` and `LDGSTS/LDGDEPBAR/DEPBAR/UISETP` neighborhoods
- the first direct combo probe under `combo_wombo_frontier_20260321_131500`
  already reproduces most of that pivot, with the remaining refinement being
  to pull `UISETP.*` into the async/cache half
- the stronger cache-policy combo under
  `combo_cache_policy_wombo_20260321_135500` now directly reproduces
  `LDG.E.U8/U16(.STRONG.GPU) + LDGSTS.E.BYPASS.LTC128B.128 + LDGDEPBAR +
  DEPBAR.LE` in one kernel, so the load/cache-policy family is now the best
  next novelty frontier
- the OptiX/callable follow-up note under
  `chain_mine_optix_callable_20260321_123500` records that the current
  callable capture does not include raw `.sass`, only PTX and runtime logs, so
  it is not an additional raw-SASS chain source on this workstation
- add `nsys` traces so Path C migration can be compared against Path A / Path B
- add cold-weight / hot-window kernels to test whether GreenBoost helps more
  when only a small active subset is repeatedly reused
- add latency-sensitive microkernels to see whether access granularity rather
  than bulk bandwidth is the dominant penalty driver

## Which sweep grants the most novelty?

For raw mnemonic novelty, use this order:

1. `--maxrregcount=32`
2. `--restrict`
3. `-Xptxas -dlcm=cg`
4. targeted predicate/uniform custom probes
5. targeted load/cache-policy custom probes

For highest raw new-count only, `--use_fast_math` also matters, but it mostly
expands the FTZ family rather than introducing new structural families.

## Which mnemonic family should be chased next?

Primary family:

- predicate / uniform:
  `P2R.B*`, byte-qualified `R2P`, `UPLOP3.LUT`, `UISETP.*`,
  `USHF.L.U64.HI`

Secondary family:

- load / cache-policy:
  `LD*`, `LDG*`, `STG*`, `LDGSTS*`

De-prioritized family:

- packed-video `V*`
  - current evidence says this frontier is effectively closed on Ada
  - only `VABSDIFF4.U8` and `VABSDIFF4.U8.ACC` survive as true packed-video raw
    SASS

## Immediate execution order

1. Check in the standalone-runner promotion already proven locally:
   - `probe_atomic_throughput`
   - `probe_l1_l2_dram_boundary`
   - `probe_nanosleep_scheduling`
2. Build dedicated runners for:
   - `probe_barrier_arrive_wait`
   - `probe_barrier_coop_groups_sync`
   - `probe_tiling_hierarchical`
3. Add the first strict predicate/uniform tranche:
   - `probe_predicate_bank_state_machine`
   - `probe_r2p_rehydrate_pipeline`
4. Add the first load-policy matrix tranche:
   - `probe_ldg_scope_policy_matrix`
5. Add the HMM runtime tranche:
   - `hmm_unified_memory_runner`

This ordering keeps the project balanced:

- it reduces runner debt
- it chases the highest-yield mnemonic frontier
- it captures the new HMM runtime frontier without confusing it for a SASS
  frontier
