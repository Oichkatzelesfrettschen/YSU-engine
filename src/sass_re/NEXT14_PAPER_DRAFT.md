SM89 Paper Draft: 14-Step Tranche
=================================

Goal
----

Turn the current Ada-only paper-ready outline material into a standalone
manuscript fragment that can be read, edited, and cited independently of the
outline.

Deliverables
------------

1. `PAPER_DRAFT_SM89.md`
2. `scripts/verify_paper_draft.py`
3. updated `PAPER_OUTLINE.md`
4. updated `PAPER_SECTION_COVERAGE.md`

Questions this tranche answers
------------------------------

1. What does the bounded Ada-only story read like as real paper prose?
2. Which claims and assets are already mature enough for manuscript insertion?
3. How do we keep the draft synchronized with the bounded claims ledger?

Acceptance criteria
-------------------

1. The repo contains a readable standalone Ada-only manuscript fragment.
2. The fragment cites the current bounded claims and generated assets.
3. A verifier checks that the fragment still references the expected claims and
   local asset files.
4. The wording stays bounded and does not imply direct source/IR emission of
   `P2R.B*` or `UPLOP3.LUT`.
