UPLOP3 Next 42: Pair-Baseline Tranche
=====================================

Goal
----

Refine the live `UPLOP3` hierarchy by treating the strongest stable pairs as the
baseline state and measuring which additional local site actually widens
semantics.

Current anchor hierarchy
------------------------

1. `uniform_occ1`
2. `cutlass_occ5`
3. `uniform_occ2`
4. `cutlass_occ4`

Current stable pair anchors
---------------------------

1. Uniform: `occ2_occ5`
2. CUTLASS: `occ2_occ5`

Questions this tranche answers
------------------------------

1. On the uniform branch, once `occ2_occ5` is already present, does adding
   `occ1` act as the main widener?
2. On the CUTLASS branch, once `occ2_occ5` is already present, does adding
   `occ4` act as the main widener?
3. Do the profiler and sanitizer lanes stay stable when the semantics widen?
4. Does the pair-baseline framing reduce the apparent importance of the weaker
   sites?

Execution steps
---------------

1. Reuse the validated tandem harness rather than creating a one-off runner.
2. Materialize a fresh uniform pair-baseline cubin (`occ2_occ5`).
3. Materialize a fresh CUTLASS pair-baseline cubin (`occ2_occ5`).
4. Run the uniform pair-baseline tandem matrix.
5. Run the CUTLASS pair-baseline tandem matrix.
6. Summarize pair-baseline fuzz deltas.
7. Summarize pair-baseline `ncu`/stall deltas.
8. Check `compute-sanitizer` cleanliness.
9. Preserve `nsys` traces.
10. Update the frontier docs with the refined pair-baseline reading.

Expected adaptation points
--------------------------

- If the uniform pair-baseline is still widened mainly by `occ1`, that
  reinforces `uniform_occ1` as the top true anchor.
- If the CUTLASS pair-baseline is widened mainly by `occ4`, that confirms
  `occ4` is the principal amplifier while `occ5` remains the trigger.
- If either branch shows a hidden perf-regime change under `ncu`, that gets
  promoted from a semantic-only note into the frontier summary.
