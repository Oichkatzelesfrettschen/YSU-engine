# Next 21 Auto-Explorer Steps

This tranche starts from the first Python auto-explorer report and immediately
executes the highest-ranked runtime-safe branch.

1. [x] Confirm the first explorer report is generated and stable.
2. [x] Confirm the top runtime proposal is `uniform_blockred_sys64_store`.
3. [x] Confirm the residual symbolic-only boundary remains `P2R.B1/B2/B3`.
4. [x] Add a reusable queue/selection helper for explorer proposals.
5. [x] Emit a ranked execution queue artifact from the first explorer run.
6. [x] Keep the queue format simple and stdlib-only.
7. [x] Reuse the existing proposal registry rather than inventing a second one.
8. [x] Build a new runtime-safe probe for the top-ranked fused branch.
9. [x] Preserve the proven uniform helper front-end:
   `ULDC.64 + UIADD3 + ULOP3.LUT + USHF`.
10. [x] Preserve the proven async/cache backbone:
    `LDGSTS + LDGDEPBAR + DEPBAR.LE`.
11. [x] Preserve the proven block-wide reductions:
    `BAR.RED.* + B2R.RESULT`.
12. [x] Preserve the proven warp helper body:
    `MATCH.ANY + REDUX.* + VOTE.*`.
13. [x] Preserve the dense 64-bit SYS atomic matrix.
14. [x] Preserve direct `LDG.E.64.STRONG.SYS` / `STG.E.64.STRONG.SYS` if possible.
15. [x] Keep the runtime path cp.async-aligned and safe.
16. [x] Add a dedicated runner for the new fused branch.
17. [x] Add a dedicated tranche script with `ncu` collection.
18. [x] Compile and disassemble the new fused branch.
19. [x] Run the new fused branch.
20. [x] Run `ncu` on the new fused branch and compare it against the existing SYS matrix.
21. [x] Update README / RESULTS / FRONTIER_ROADMAP with the new branch and the explorer-driven flow.
