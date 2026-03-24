# Next 120 P2R Phase-3 Steps

This phase assumes ordinary CUDA C++ source-space is exhausted and focuses on
binary-motif seeds, constrained PTX mutation, and cubin-side semantic
validation.

## Scope

1. [x] Capture the phase-3 objective around direct local optimized `sm_89`
   `P2R.B1/B2/B3`.
2. [x] Treat plain `P2R` as necessary but insufficient evidence.
3. [x] Treat cuDNN precompiled windows as the primary motif oracle.
4. [x] Treat cuBLAS/TensorRT non-hits as negative controls.
5. [x] Treat Triton as a distinct frontend basin, not an unlock.
6. [x] Treat direct PTX version sweeps as version-insensitive for the simple
   branch.
7. [x] Treat cross-version `nvcc -G` as blocked by sysroot/glibc, not GCC.
8. [x] Extract exact `B2/B3` motif seeds into machine-readable form.
9. [x] Normalize seed classes by predecessor/successor family.
10. [x] Normalize seed classes by immediate mask family.
11. [x] Normalize seed classes by memory-side companions.
12. [x] Normalize seed classes by control-side companions.
13. [x] Normalize seed classes by arithmetic-side companions.
14. [x] Normalize seed classes by `R2P` adjacency.
15. [x] Normalize seed classes by byte-lane ordering.
16. [x] Separate `B2`-only seeds from `B2->B3` chains.
17. [x] Separate `B3`-only seeds from `B3->R2P` chains.
18. [x] Export seed registry JSON.
19. [x] Export seed registry summary text.
20. [x] Rank seeds by frequency and novelty.

## Seeded PTX Search

21. [x] Build constrained mutator scaffold from seed registry.
22. [ ] Generate `B2 -> R2P -> LEA -> LEA.HI.X` approximations.
23. [ ] Generate `B2 -> BAR.SYNC -> ULDC` approximations.
24. [ ] Generate `B3 -> BAR.SYNC -> ULDC` approximations.
25. [ ] Generate `B3 -> R2P -> LDGSTS` approximations.
26. [ ] Generate `B2 -> P2R.B3` staged approximations.
27. [ ] Generate `ISETP.GE`-weighted variants.
28. [ ] Generate `ISETP.LT`-weighted variants.
29. [ ] Generate `shared64` memory variants.
30. [ ] Generate `shared32` memory variants.
31. [ ] Generate `BAR.SYNC.DEFER_BLOCKING`-leaning variants.
32. [ ] Generate `ULDC.64`-leaning variants.
33. [ ] Generate `LDS.64`-leaning variants.
34. [ ] Generate `LEA/LEA.HI.X` arithmetic approximations.
35. [ ] Generate `IADD3`-weighted control approximations.
36. [ ] Generate mixed `ULDC + LDS + BAR` approximations.
37. [x] Run on CUDA 13.1 `ptxas`.
38. [x] Run on sidecar 12.6 `ptxas`.
39. [x] Run on sidecar 11.8 `ptxas`.
40. [x] Compare qualitative invariance across all three.

## Patchpoint Discovery

41. [x] Collect strongest local plain-`P2R` O3 cubins.
42. [x] Collect strongest local plain-`P2R 0x7f` sites.
43. [x] Collect strongest local plain-`P2R 0xf` sites.
44. [x] Rank local sites by overlap to `B2` motifs.
45. [x] Rank local sites by overlap to `B3` motifs.
46. [x] Rank local sites by overlap to `R2P/LEA` motifs.
47. [x] Rank local sites by overlap to `BAR/ULDC` motifs.
48. [x] Rank local sites by overlap to `LDGSTS` motifs.
49. [x] Emit patchpoint summary.
50. [x] Emit patchpoint JSON.
51. [x] Identify best `B2` candidate site.
52. [x] Identify best `B3` candidate site.
53. [ ] Identify best `B2->B3` chain candidate site.
54. [ ] Identify best control-rich candidate site.
55. [ ] Identify best memory-rich candidate site.
56. [x] Identify lowest-risk patch target.
57. [ ] Identify highest-fidelity patch target.
58. [ ] Document rejected weak targets.
59. [ ] Compare patchpoint classes to cuDNN windows.
60. [x] Freeze first semantic-validation candidates.

## Cubin-Side Validation Prep

61. [x] Determine which plain `P2R` sites are byte-lane-adjacent enough to patch.
62. [x] Determine which local sites already carry compatible masks.
63. [ ] Determine which local sites need control-neighbor preservation.
64. [ ] Determine which local sites need memory-neighbor preservation.
65. [ ] Determine whether `R2P` adjacency can be represented nearby.
66. [x] Determine whether patch target should be `B2`.
67. [x] Determine whether patch target should be `B3`.
68. [ ] Determine whether patch target should be a chained `B2->B3`.
69. [x] Produce first semantic patch sketch.
70. [x] Produce second semantic patch sketch.
71. [x] Produce first safety checklist for patch execution.
72. [x] Produce first rollback checklist.
73. [x] Produce patchpoint evidence bundle.
74. [ ] Produce local-vs-library opcode delta table.
75. [x] Produce patchable-candidate shortlist.
76. [x] Decide whether first patch should stay symbolic-only.
77. [x] Decide whether first patch should be executed.
78. [x] Decide first validation harness.
79. [x] Decide first disassembly validation harness.
80. [x] Decide first runtime safety harness.

## Extended Search

81. [ ] Add second-wave seeds from exact `B2/B3` triplets.
82. [ ] Add third-wave seeds from `B2->B3->BAR->ULDC`.
83. [ ] Add fourth-wave seeds from `B3->R2P->LDGSTS`.
84. [ ] Add fifth-wave seeds from `B2->R2P->LEA.HI.X`.
85. [ ] Add negative-control seeds from failed PTX variants.
86. [ ] Score mutator outputs by neighborhood closeness.
87. [ ] Score mutator outputs by byte-lane plausibility.
88. [ ] Score mutator outputs by local patchability.
89. [ ] Score mutator outputs by cross-version stability.
90. [ ] Emit ranked mutator frontier.
91. [ ] Compare mutator frontier to local source-space winners.
92. [ ] Compare mutator frontier to Triton basin.
93. [ ] Compare mutator frontier to clang basin.
94. [ ] Compare mutator frontier to direct PTX basin.
95. [ ] Collapse duplicate motif classes.
96. [ ] Re-rank by binary-side evidence.
97. [x] Re-rank by semantic patch friendliness.
98. [ ] Re-rank by reproducibility.
99. [ ] Mark exhausted motif classes.
100. [ ] Mark live motif classes.

## Final Consolidation

101. [ ] Update `P2R_NEXT_PHASE.md`.
102. [ ] Update `P2R_FRONTIER_ANALYSIS.md`.
103. [ ] Update `RESULTS.md`.
104. [ ] Update `README.md`.
105. [ ] Update `AUTO_EXPLORER.md`.
106. [ ] Record exact sidecar GCC/glibc limitation.
107. [ ] Record exact sidecar `nvcc -G` limitation.
108. [ ] Record exact version-invariant PTX result.
109. [ ] Record exact motif-seeded PTX result.
110. [ ] Record exact patchpoint shortlist.
111. [x] Record exact semantic-validation entrypoint.
112. [ ] State whether `P2R.B*` remains unreproduced from standalone source/IR.
113. [ ] State whether binary motifs are sufficient for patchpoint selection.
114. [x] State whether first cubin patch should proceed.
115. [ ] State whether an older sysroot container is still worth adding.
116. [ ] State whether more library mining is still warranted.
117. [ ] State the minimal remaining unknowns.
118. [ ] Freeze the phase-3 boundary.
119. [x] Queue the first executed semantic-validation patch if justified.
120. [ ] Summarize the final last-frontier RCA.
