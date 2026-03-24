# Next 120 Auto-Explorer Steps

This tranche starts after the first executed explorer-guided fused branch and
keeps the loop grounded in real runtime evidence.

## Phase A: Immediate follow-ups on the executed top branch

1. [x] Confirm the first executed explorer pick is runtime-safe.
2. [x] Confirm it preserves the intended fused family.
3. [x] Confirm it also picks up optimized `BSSY` and `BSYNC`.
4. [x] Run the same fused branch under `-dlcm=cg`.
5. [x] Measure whether the stronger L2 policy changes cycles materially.
6. [x] Measure whether the stronger L2 policy changes the stall split materially.
7. [x] Compare the `-dlcm=cg` fused branch against the store-side SYS-safe baseline.
8. [x] Compare the `-dlcm=cg` fused branch against the executed default fused branch.

## Phase B: Structural-depth follow-up

9. [x] Build a deeper runtime-safe fused branch.
10. [x] Preserve the uniform helper front-end.
11. [x] Preserve the async/cache backbone.
12. [x] Preserve block-red helpers.
13. [x] Preserve warp helper adjacency.
14. [x] Preserve the dense SYS64 atomic matrix.
15. [x] Preserve direct SYS load/store.
16. [x] Keep the path aligned and runtime-safe.
17. [x] Add a dedicated runner.
18. [x] Add a dedicated tranche script.
19. [x] Compile and disassemble the depth-safe fused branch.
20. [x] Run the depth-safe fused branch.
21. [x] Run `ncu` on the depth-safe fused branch.
22. [x] Compare it against the executed default fused branch.
23. [x] Compare it against the deep non-uniform SYS-safe branch.

## Phase C: Explorer refresh and queue refresh

24. [x] Refresh the explorer on the enlarged runtime-safe corpus.
25. [x] Refresh the queue artifact.
26. [x] Check whether the executed branch still appears as effectively unseen.
27. [x] If needed, tighten candidate bookkeeping around emergent divergence.
28. [x] Re-rank the next runtime frontier after the two follow-ups land.

## Phase D: Immediate next runtime-safe conversion targets

29. [x] Re-evaluate `uniform_divergent_sys64` after the refreshed explorer run.
30. [x] Re-evaluate `narrow_atomg_sys64_dlcm_cg`.
31. [x] Re-evaluate `uniform_blockred_sys64_store_dlcm_cg`.
32. [x] Re-evaluate `uniform_blockred_sys64_depth`.
33. [x] Re-evaluate `divergent_store_sys64`.

## Phase E: Symbolic boundary discipline

34. [x] Keep the residual raw-SASS boundary pinned to `P2R.B1/B2/B3`.
35. [x] Avoid broad random symbolic sweeps while the runtime-safe branch is yielding.
36. [x] Preserve the existing `P2R.B*` retry queue in the explorer outputs.

## Phase F: Correlation and summarization

37. [x] Add the new fused `-dlcm=cg` branch to the narrative matrix.
38. [x] Add the new fused depth branch to the narrative matrix.
39. [x] Compare scoreboard vs membar scaling on the fused family.
40. [x] Compare L2 hit movement vs cycle movement on the fused family.
41. [x] Re-state the current best frontier after these follow-ups.

## Phase G: Parser and bridge follow-ups

45. [x] Fix the explorer to ingest long-form Nsight Compute CSV output.
46. [x] Re-run the explorer on the narrow SYS64 follow-ups after the parser fix.
47. [x] Build a runtime-safe uniform + divergent + SYS64 bridge.
48. [x] Profile the uniform + divergent + SYS64 bridge under `ncu`.
49. [x] Compare the uniform + divergent bridge against the lighter uniform and heavier SYS-store families.
50. [x] Build a runtime-safe divergent + SYS64 store bridge.
51. [x] Profile the divergent + SYS64 store bridge under `ncu`.
52. [x] Compare the divergent store bridge against the earlier divergent no-store branch.
53. [x] Compare the divergent store bridge under `-dlcm=cg`.
54. [x] Refresh the explorer again after the two new bridge branches land.
55. [x] Refresh the queue again after the two new bridge branches land.
56. [x] Preserve the symbolic `P2R.B*` boundary while expanding the runtime matrix.

## Remaining tranche budget

42. [x] Use the remaining budget on the best-yielding runtime-safe branch first.
43. [x] Only widen sideways once the current fused family flattens.
44. [x] Keep queue generation, execution, and doc harvest coupled together.

## Phase H: Uniform + SYS64 bridge deepening

57. [x] Build a uniform + block-red + SYS64 depth-safe branch without direct SYS store.
58. [x] Confirm it preserves `ULDC/UIADD3/ULOP3/USHF` in executable SASS.
59. [x] Confirm it still preserves `BAR.RED.*`, `B2R.RESULT`, and the dense `ATOMG.E.*.64.STRONG.SYS` block.
60. [x] Run `ncu` on the uniform + block-red + SYS64 depth-safe branch.
61. [x] Compare whether this non-store depth branch shifts pressure toward long-scoreboard or membar.
62. [x] Build the aggressive uniform + divergent + block-red + SYS64 + direct SYS store branch.
63. [x] Confirm it preserves direct `LDG.E.64.STRONG.SYS` / `STG.E.64.STRONG.SYS` together with the uniform helper front-end.
64. [x] Run `ncu` on the aggressive uniform + divergent + SYS64 store branch.
65. [x] Compare it against the non-uniform divergent SYS-store bridge.
66. [x] Compare it against the earlier uniform + divergent no-store bridge.
67. [x] Run the aggressive uniform + divergent + SYS64 store branch under `-dlcm=cg`.
68. [x] Measure whether `-dlcm=cg` helps or hurts this fully fused branch.
69. [x] Refresh the explorer after the new uniform + SYS64 branches land.
70. [x] Refresh the queue after the new uniform + SYS64 branches land.
