# Monograph Processed Data Archive

This directory contains plot-ready and monograph-ready processed tables derived
from the current SM89 paper assets and runtime summaries.

Files:

- `inventory_numeric.csv`
  - normalized inventory and frontier counts
- `p2r_frontier_numeric.csv`
  - encoded `P2R` frontier status table with simple state scores
- `uplop3_runtime_class_counts.csv`
  - inert vs stable-but-different class counts
- `uplop3_runtime_sites.csv`
  - site-level runtime-class listing
- `uplop3_live_site_numeric.csv`
  - live-site rank, role, jaccard, and distance-to-1
- `uplop3_pair_baseline_numeric.csv`
  - pair-baseline same/diff counts and normalized diff ratios
- `tool_effectiveness_numeric.csv`
  - normalized tool-role priorities for semantic workflow plots

Primary producer:

- [generate_monograph_assets.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/generate_monograph_assets.py)

Primary consumers:

- [MONOGRAPH_SM89_SYNTHESIS.md](/home/eirikr/Github/YSU-engine/src/sass_re/MONOGRAPH_SM89_SYNTHESIS.md)
- [sm89_monograph.tex](/home/eirikr/Github/YSU-engine/src/sass_re/tex/sm89_monograph.tex)
