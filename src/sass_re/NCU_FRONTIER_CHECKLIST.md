# Combo-Family NCU Frontier Checklist

This checklist scopes the next 84 evidence-bearing items for the SM89 combo
family. It is intentionally `ncu`-first: batch safe executable anchors first,
then widen into policy, scope, symbolic/runtime bridge cases, and only then
return to the residual raw mnemonic gap.

## Batch and inventory

1. [x] Reconfirm the runnable combo-family anchor inventory.
2. [x] Reconfirm the existing tranche scripts for each safe anchor.
3. [x] Reconfirm the current summary scripts and matrix artifacts.
4. [x] Add a dedicated combo-family `ncu` batch driver.
5. [x] Add a dedicated combo-family `ncu` matrix summarizer.
6. [x] Batch the smaller safe default branch.
7. [x] Batch the smaller safe `-dlcm=cg` branch.
8. [x] Batch the smaller safe depth branch.
9. [x] Batch the smaller safe depth `-dlcm=cg` branch.
10. [x] Batch the 64-bit SYS-safe default branch.
11. [x] Batch the 64-bit SYS-safe `-dlcm=cg` branch.
12. [x] Batch the deeper 64-bit SYS-safe default branch.

## Store-side safe branch

13. [x] Batch the store-side SYS-safe default branch.
14. [x] Batch the store-side SYS-safe `-dlcm=cg` branch.
15. [x] Confirm direct `LDG.E.64.STRONG.SYS` survives in executable SASS.
16. [x] Confirm direct `STG.E.64.STRONG.SYS` survives in executable SASS.
17. [x] Compare store-side default vs store-side `-dlcm=cg`.
18. [x] Compare store-side branch vs deeper SYS-safe branch.
19. [ ] Quantify whether the store-side branch shifts long-scoreboard.
20. [ ] Quantify whether the store-side branch shifts membar.
21. [ ] Quantify whether the store-side branch shifts wait.
22. [ ] Quantify whether the store-side branch shifts L2 hit rate.
23. [ ] Record the first trustworthy store-side runtime boundary.
24. [ ] Fold the store-side runtime boundary into docs.

## Smaller safe branch scaling

25. [x] Reconfirm the shallow small-family anchor under the batch driver.
26. [x] Reconfirm the shallow small-family `-dlcm=cg` lane under the batch driver.
27. [x] Reconfirm the deeper small-family anchor under the batch driver.
28. [x] Reconfirm the deeper small-family `-dlcm=cg` lane under the batch driver.
29. [x] Quantify shallow vs deep instruction growth on the small family.
30. [x] Quantify shallow vs deep register growth on the small family.
31. [x] Quantify shallow vs deep shared-memory growth on the small family.
32. [x] Quantify shallow vs deep short-scoreboard growth on the small family.
33. [x] Quantify shallow vs deep long-scoreboard movement on the small family.
34. [x] Quantify shallow vs deep wait growth on the small family.
35. [x] Confirm barrier remains negligible on the small family.
36. [x] Confirm membar remains negligible on the small family.

## 64-bit SYS-safe scaling

37. [x] Reconfirm the shallow 64-bit SYS-safe branch under the batch driver.
38. [x] Reconfirm the shallow 64-bit SYS-safe `-dlcm=cg` lane.
39. [x] Reconfirm the deeper 64-bit SYS-safe branch.
40. [x] Compare shallow vs deep 64-bit SYS-safe cycles.
41. [x] Compare shallow vs deep 64-bit SYS-safe instruction count.
42. [x] Compare shallow vs deep 64-bit SYS-safe register count.
43. [x] Compare shallow vs deep 64-bit SYS-safe shared-memory footprint.
44. [x] Compare shallow vs deep 64-bit SYS-safe long-scoreboard.
45. [x] Compare shallow vs deep 64-bit SYS-safe membar.
46. [x] Compare shallow vs deep 64-bit SYS-safe short-scoreboard.
47. [x] Compare shallow vs deep 64-bit SYS-safe wait.
48. [x] Decide whether this branch is scoreboard-first or membar-first.

## Policy and scope interpretation

49. [x] Quantify `-dlcm=cg` effect on cycles for the small family.
50. [x] Quantify `-dlcm=cg` effect on cycles for the shallow 64-bit SYS-safe family.
51. [x] Quantify `-dlcm=cg` effect on cycles for the store-side SYS-safe family.
52. [x] Quantify `-dlcm=cg` effect on L2 hit rate for the small family.
53. [x] Quantify `-dlcm=cg` effect on L2 hit rate for the shallow 64-bit SYS-safe family.
54. [x] Quantify `-dlcm=cg` effect on L2 hit rate for the store-side SYS-safe family.
55. [x] Quantify `-dlcm=cg` effect on long-scoreboard for the small family.
56. [x] Quantify `-dlcm=cg` effect on long-scoreboard for the shallow 64-bit SYS-safe family.
57. [x] Quantify `-dlcm=cg` effect on long-scoreboard for the store-side SYS-safe family.
58. [x] Quantify `-dlcm=cg` effect on membar for the shallow 64-bit SYS-safe family.
59. [x] Quantify `-dlcm=cg` effect on membar for the store-side SYS-safe family.
60. [x] Re-state the current policy rule for the whole combo family.

## Symbolic/runtime bridge

61. [ ] Keep the symbolic-only store-side kernel in the frontier ledger.
62. [ ] Keep the safe store-side surrogate in the runtime ledger.
63. [ ] Compare symbolic store-side emitted SASS vs safe store-side emitted SASS.
64. [ ] Confirm the safe store-side surrogate preserves the direct SYS load/store pair.
65. [ ] Confirm the safe store-side surrogate preserves the dense SYS ATOMG block.
66. [ ] Confirm the safe store-side surrogate preserves the block-red helpers.
67. [ ] Confirm the safe store-side surrogate preserves the warp-side helpers.
68. [ ] Confirm the safe store-side surrogate preserves the async/cache backbone.
69. [ ] Record which symbolic-only mnemonics still have no safe runtime twin.
70. [ ] Record which runtime-safe branches now fully close the symbolic/runtime gap.
71. [ ] Re-rank runtime-safe branches by interpretive value.
72. [ ] Re-rank symbolic-only branches by likely next conversion value.

## Chain and adjacency mining

73. [ ] Regenerate a combo-family chain matrix from the batched safe runs.
74. [ ] Compare small safe vs shallow SYS-safe adjacency windows.
75. [ ] Compare shallow SYS-safe vs deep SYS-safe adjacency windows.
76. [ ] Compare deep SYS-safe vs store-side SYS-safe adjacency windows.
77. [ ] Record the strongest runtime-safe adjacency anchor.
78. [ ] Record the strongest symbolic-only adjacency anchor.
79. [ ] Record the current best mixed async/cache + SYS control anchor.
80. [ ] Record the current best block-red + warp + SYS atomic anchor.

## Residual frontier and harvest

81. [ ] Re-state the residual raw-SASS gap after the batch (`P2R.B1/B2/B3`).
82. [x] Update README with the new combo-family `ncu` matrix.
83. [x] Update RESULTS with the new combo-family `ncu` matrix.
84. [x] Update FRONTIER_ROADMAP with the re-ranked next frontier after the batch.
