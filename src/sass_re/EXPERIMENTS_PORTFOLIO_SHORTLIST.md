# SM89 Experiments Portfolio Shortlist

This shortlist clusters the current SM89 artifact families into paper-facing
experiment units.

## Theme 1: Inventory Closure

Artifacts:

- [RESULTS.md](/home/eirikr/Github/YSU-engine/src/sass_re/RESULTS.md)
- [SM89_SASS_INSTRUCTION_REFERENCE.md](/home/eirikr/Github/YSU-engine/src/sass_re/SM89_SASS_INSTRUCTION_REFERENCE.md)
- [table_a1_sm89_inventory_summary.csv](/home/eirikr/Github/YSU-engine/src/sass_re/tables/table_a1_sm89_inventory_summary.csv)

Method summary:

This theme compresses the broad recursive probe corpus into a bounded inventory
statement. Its value is not only the `379/382/470` counts, but the fact that
those counts shrink the remaining open problem into a tiny unresolved
direct-local source/IR cluster.

Figure/table target:

- inventory closure bar chart

Validation check:

- [verify_paper_assets.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/verify_paper_assets.py)

## Theme 2: `P2R` Frontier

Artifacts:

- [P2R_FRONTIER_ANALYSIS.md](/home/eirikr/Github/YSU-engine/src/sass_re/P2R_FRONTIER_ANALYSIS.md)
- [P2R_NEXT_PHASE.md](/home/eirikr/Github/YSU-engine/src/sass_re/P2R_NEXT_PHASE.md)
- [table_a2_p2r_frontier_status.csv](/home/eirikr/Github/YSU-engine/src/sass_re/tables/table_a2_p2r_frontier_status.csv)

Method summary:

This theme moves the `P2R.B*` question from brute-force search into RCA. It
separates neighborhood reproduction, direct source/IR selection failure, and
cubin-side opcode validity.

Figure/table target:

- `P2R` frontier ladder/state chart

Validation check:

- `P2R.B1/B2/B3` remain source/IR-negative but cubin-side-positive

## Theme 3: `UPLOP3` Structural Boundary

Artifacts:

- [UPLOP3_FRONTIER_ANALYSIS.md](/home/eirikr/Github/YSU-engine/src/sass_re/UPLOP3_FRONTIER_ANALYSIS.md)
- [table_a3_uplop3_structural_boundary.csv](/home/eirikr/Github/YSU-engine/src/sass_re/tables/table_a3_uplop3_structural_boundary.csv)
- [uplop3_runtime_class_map.generated.svg](/home/eirikr/Github/YSU-engine/src/sass_re/figures/uplop3_runtime_class_map.generated.svg)

Method summary:

This theme establishes the local structural law for `UPLOP3`: `ULOP3` is the
wrong patch substrate, `PLOP3` is the right one. The result is stronger than a
decode table because it crosses into runtime semantic classes.

Figure/table target:

- runtime-class map and structural-boundary table

Validation check:

- inert vs stable-but-different runtime classes remain reproducible

## Theme 4: Live-Site Semantics

Artifacts:

- [table_a4_live_uplop3_site_ranking.csv](/home/eirikr/Github/YSU-engine/src/sass_re/tables/table_a4_live_uplop3_site_ranking.csv)
- [uplop3_pair_baseline_numeric.csv](/home/eirikr/Github/YSU-engine/src/sass_re/processed/monograph_20260323/uplop3_pair_baseline_numeric.csv)
- [MONOGRAPH_SM89_SYNTHESIS.md](/home/eirikr/Github/YSU-engine/src/sass_re/MONOGRAPH_SM89_SYNTHESIS.md)

Method summary:

This theme resolves the live `UPLOP3` sites into anchors, sensitizers, and
amplifiers using pair-baseline analysis and differential fuzzing.

Figure/table target:

- live-site ranking chart
- pair-baseline divergence-ratio chart

Validation check:

- anchor/modifier ordering remains consistent with the tandem summaries

## Theme 5: Toolchain Law

Artifacts:

- [table_a5_tool_effectiveness_matrix.csv](/home/eirikr/Github/YSU-engine/src/sass_re/tables/table_a5_tool_effectiveness_matrix.csv)
- [KNOWLEDGE_SYNTHESIS.md](/home/eirikr/Github/YSU-engine/src/sass_re/KNOWLEDGE_SYNTHESIS.md)

Method summary:

This theme explains which observability tools answer which questions. It keeps
semantic ranking, safety checking, performance sanity, and trace provenance
separate rather than collapsing them into one notion of "profiling."

Figure/table target:

- tool-role matrix or semantic-priority bar chart

Validation check:

- `ncu` and `compute-sanitizer` continue to play different roles in the
  narrative and in the data
