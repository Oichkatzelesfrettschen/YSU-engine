# Next 25 P2R Phase-2 Steps

1. [x] Confirm local environment feasibility for PTX/frontend sweeps.
2. [x] Launch broad installed-library `P2R.B*` mining.
3. [x] Launch first direct PTX predicate-logic search.
4. [x] Capture next-phase scope in [P2R_NEXT_PHASE.md](/home/eirikr/Github/YSU-engine/src/sass_re/P2R_NEXT_PHASE.md).
5. [x] Verify that cuBLAS contributes no immediate `P2R.B*` hits in the first sweep.
6. [x] Verify that TensorRT `sm89` builder resource is not directly `cuobjdump`-readable.
7. [x] Summarize cuDNN mined `P2R.B1` predecessor op frequencies.
8. [x] Summarize cuDNN mined `P2R.B2` predecessor op frequencies.
9. [x] Summarize cuDNN mined `P2R.B3` predecessor op frequencies.
10. [x] Compare those frequency tables against the best local B1/B2/B3 probes.
11. [x] Promote the strongest missing predecessor motifs into PTX variants.
12. [x] Run a second PTX batch with those mined motifs.
13. [x] Try a direct clang CUDA frontend path on one best B1 probe.
14. [x] If clang works, capture emitted LLVM IR and PTX as comparison artifacts.
15. [x] Try a minimal Triton predicate-pack kernel and capture its PTX.
16. [x] Compare Triton PTX motifs against the direct PTX search motifs.
17. [x] Rank which frontend path perturbs predicate-source kind most.
18. [x] Decide whether a CUDA 11.8-capable side toolchain is worth installing.
19. [x] If yes, add a side-by-side toolchain env layout that preserves CUDA 13.x as default.
20. [x] Avoid CUDA 10 and pre-11.8 installs for Ada direct-local testing.
21. [x] If a second toolchain is added, rerun the strongest B1/B2 PTX variants there.
22. [ ] If TensorRT still matters, inspect its sections/packaging rather than plain `cuobjdump`.
23. [ ] Add constrained mutator seeds from the newly mined `B2/B3 -> R2P/LEA` and `BAR.SYNC/ULDC` motifs.
24. [x] Re-rank the remaining frontier after PTX/frontend/library results.
25. [x] Decide whether to escalate to cubin surgery for semantic validation.

Current decision:

- yes, if the next constrained mutator seeds still fail, the next meaningful
  escalation is cubin-side semantic validation rather than more random
  source-space mutation
