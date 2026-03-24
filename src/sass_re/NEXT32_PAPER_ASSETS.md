SM89 Paper Assets: 32-Step Tranche
==================================

Goal
----

Turn the current SM89 synthesis and claims ledger into directly usable paper
assets instead of leaving the outline at the "placeholder table" stage.

Asset targets
-------------

1. `PAPER_ASSETS_SM89.md`
2. `PAPER_SECTION_COVERAGE.md`
3. `scripts/verify_paper_assets.py`

Questions this tranche answers
------------------------------

1. Which paper tables can already be instantiated from current SM89 evidence?
2. Which figure specs are concrete enough to hand off for rendering later?
3. Which outline sections are already supportable with Ada-only bounded claims?
4. Which sections still depend on Pascal-side evidence and must remain blocked?

Acceptance criteria
-------------------

1. The paper outline references concrete paper assets, not just plans.
2. The strongest current SM89 claims have table/figure homes.
3. A verifier checks claim IDs and paper asset file references.
4. The wording stays bounded: no accidental claim that direct source/IR emits
   `P2R.B*` or `UPLOP3.LUT`.
