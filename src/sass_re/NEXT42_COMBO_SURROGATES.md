# Next 42 Combo-Surrogate Steps

This tranche starts from the completed combo-family `ncu` batch and moves
deeper into the remaining symbolic-only 64-bit/cache frontier.

## Scope reset

1. [x] Confirm the broad combo-family `ncu` batch is complete.
2. [x] Confirm the residual raw-SASS-only mnemonic gap remains `P2R.B1/B2/B3`.
3. [x] Confirm the two named priorities already have safe runtime twins:
   `probe_combo_blockred_warp_atomg64sys_ops_cache_wombo.cu` ->
   `probe_combo_blockred_warp_atomg64sys_ops_profile_safe.cu`
   and
   `probe_combo_store64sys_cache_wombo.cu` ->
   `probe_combo_blockred_warp_atomg64sys_ops_store_profile_safe.cu`.
4. [x] Identify the next true symbolic-only 64-bit/cache probes.
5. [ ] Re-rank those symbolic-only probes by expected runtime yield.

## Narrow 64-bit ATOMG matrix branch

6. [ ] Design a safe surrogate for `probe_combo_atomg64sys_ops_cache_wombo.cu`.
7. [ ] Preserve `LDG.E.64(.STRONG.GPU)` in the safe surrogate.
8. [ ] Preserve `LDGSTS.E.BYPASS.LTC128B.128(.ZFILL)` in the safe surrogate.
9. [ ] Preserve `LDGDEPBAR + DEPBAR.LE` in the safe surrogate.
10. [ ] Preserve the full `ATOMG.E.ADD/MIN/MAX/AND/OR/XOR.64.STRONG.SYS` matrix.
11. [ ] Preserve `MEMBAR.SC.SYS`.
12. [ ] Preserve `ERRBAR`.
13. [ ] Preserve `CCTL.IVALL`.
14. [ ] Keep the runtime path aligned and cp.async-safe.
15. [ ] Add a dedicated runner.
16. [ ] Add a dedicated tranche script.
17. [ ] Compile and disassemble the new narrow safe surrogate.
18. [ ] Run the narrow safe surrogate.
19. [ ] Run `ncu` on the narrow safe surrogate.
20. [ ] Compare the narrow safe surrogate against the shallow SYS-safe branch.
21. [ ] Compare the narrow safe surrogate against the deep SYS-safe branch.
22. [ ] Compare the narrow safe surrogate against the store-side SYS-safe branch.

## Divergent / reconvergence branch

23. [ ] Design a safe surrogate for `probe_combo_divergent_blockred_warp_atomg64sys_ops_cache_wombo.cu`.
24. [ ] Preserve `BSSY`.
25. [ ] Preserve `BSYNC`.
26. [ ] Preserve the fused block-red helpers.
27. [ ] Preserve `MATCH/VOTE/REDUX`.
28. [ ] Preserve the dense 64-bit SYS `ATOMG` matrix.
29. [ ] Keep the runtime path aligned and warp-safe.
30. [ ] Add a dedicated runner.
31. [ ] Add a dedicated tranche script.
32. [ ] Compile and disassemble the divergent safe surrogate.
33. [ ] Run the divergent safe surrogate.
34. [ ] Run `ncu` on the divergent safe surrogate.
35. [ ] Compare optimized reconvergence stalls against the current SYS-safe matrix.

## Uniform / mixed branches

36. [ ] Decide whether `probe_combo_uniform_stage_redsys_wombo.cu` or another uniform branch is the next runtime conversion after the narrow and divergent surrogates.
37. [ ] Compare the existing uniform-helper runtime branch against the small safe family.
38. [ ] Compare the existing uniform-helper runtime branch against the heavy SYS-safe family.

## Harvest

39. [ ] Update README with the next surrogate result.
40. [ ] Update RESULTS with the next surrogate result.
41. [ ] Update FRONTIER_ROADMAP with the revised ranking.
42. [ ] Re-state the next symbolic-only branches after these conversions land.
