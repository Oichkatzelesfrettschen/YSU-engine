# P2R Frontier Analysis

This memo answers four questions:

1. What are we actually looking for?
2. What have we already tried?
3. What does the normalized data say?
4. What new methods could plausibly break through?

## The Exact Target

The target is narrow and concrete:

- direct local optimized SASS on `sm_89`
- emitted from local source or local frontend experiments
- containing any of:
  - `P2R.B1`
  - `P2R.B2`
  - `P2R.B3`

Things that do not count as closing the frontier:

- library-mined evidence only
- plain `P2R`
- debug-only neighbors
- nearby control/predicate helpers such as `PLOP3.LUT` by themselves

So the search is not "find anything P2R-shaped." The search is:

- force byte-qualified `P2R.B*` form selection locally

## What We Are Looking For, More Specifically

The cuDNN-mined reference pockets suggest three things at once:

1. There is a live packed predicate-bank path.
2. The packed carrier stays alive across multiple byte updates.
3. The compiler or assembler chooses a byte-qualified `P2R.B*` form instead of
   plain `P2R` plus extra GPR glue.

That means the real unknown is not the neighborhood anymore. The real unknown
is the final form-selection rule.

## What We Tried

### 1. Carrier-shape mutations

Tried:

- same-carrier full-mask `0x7f`
- split-seed carriers
- late-carried higher-byte updates
- whole-register regmask rewrites
- dualpack transitions
- second-bank halfword staging
- staged tripack prefix lifetimes

Result:

- these improve closeness to the reference
- they do not emit `P2R.B*`

### 2. Pack-width mutations

Tried:

- `0x7f`
- `0x0f`
- transition variants of `0x0f`

Result:

- local code can emit plain `P2R ... 0x7f`
- local code can emit plain `P2R ... 0x0f`
- width alone is not the missing ingredient

### 3. Source-kind mutations

Tried:

- mostly `ISETP`-driven predicate banks
- dense optimized `LOP3.LUT P*`
- dense optimized `PLOP3.LUT`
- fused `PLOP3` plus same-carrier lifetimes
- fused `PLOP3` plus explicit `SEL`-weighted packing

Result:

- predicate-source kind is real
- it changes the optimized emitted neighborhood
- but it still does not trigger `P2R.B*`

### 4. Compiler-pressure mutations

Tried:

- plain `-O3 -Xptxas -O3`
- `--maxrregcount=32`

Result:

- these change other frontiers
- they do not flip the last `P2R.B*` boundary

## Normalized Read of the Data

The normalized analysis artifact is:

- [summary.txt](results/runs/p2r_frontier_analysis_20260322_204026/summary.txt)

The strongest source-space approximations are:

- `probe_p2r_b1_samecarrier_r7style_exact`
- `probe_p2r_b1_dualpack_transition_exact`
- `probe_p2r_b1_nibble_transition_exact`
- `probe_p2r_b1_regmask_transition_exact`
- `probe_p2r_b1_split_seed_exact`

Important normalized findings:

- `B1` is the closest local target by a clear margin.
- `B2` is worse than `B1`, but still somewhat responsive to tripack-prefix
  staging.
- `B3` is the weakest local target.
- `PRMT` correlates with weaker `B3`-shaped paths.
- `same-carrier` and `dualpack` are the strongest source-space families.
- `PLOP3`-fed probes reproduce the predicate neighborhood we wanted, but still
  do not cause byte-qualified selection.

## Interpretation

The frontier has changed from a discovery problem into a control problem.

We are no longer missing the neighborhood:

- we have plain `P2R ... 0x7f`
- we have plain `P2R ... 0x0f`
- we have dense optimized `PLOP3.LUT`
- we have dense optimized `LOP3.LUT P*`
- we have same-carrier and split-seed lifetimes

What we still do not have is the form-selection step that picks:

- `P2R.B1/B2/B3`

That makes the strongest current conclusion:

- ordinary CUDA C++ source shaping is probably not enough on this local
  toolchain

## Why The Last Three PLOP3 Runs Matter

The final three runs are:

- [p2r_plop3_source_20260322_202900](results/runs/p2r_plop3_source_20260322_202900)
- [p2r_plop3_samecarrier_20260322_202951](results/runs/p2r_plop3_samecarrier_20260322_202951)
- [p2r_plop3_selpack_20260322_203047](results/runs/p2r_plop3_selpack_20260322_203047)

These close the last meaningful source-space axis:

- they reproduce dense optimized predicate-`LOP3`
- they reproduce dense optimized `PLOP3`
- they test both same-carrier and explicit weighted-pack styles

And still:

- no `P2R.B1`
- no `P2R.B2`
- no `P2R.B3`

More sharply, they show two failure modes:

1. simpler tripack shapes keep plain `P2R ..., RZ, 0x1`
2. richer fused shapes often drop `P2R` entirely and rebuild bytes with
   `SEL` plus `LOP3`

That is exactly the kind of evidence that says "source-space exhausted."

## What Pattern Recognition Helps Now

The most useful pattern recognition is not a giant black-box model.
It is a normalization layer over experiment axes:

- target byte: `B1`, `B2`, `B3`
- source kind: `ISETP`-heavy vs `PLOP3`-fed
- carrier style: same-carrier, split-seed, regmask, tripack-prefix, nibble
- pack style: `0x7f`, `0x0f`, weighted `SEL`-pack
- prefix state: none, `0x80` split, prior-byte-prefix
- emitted glue: `PRMT`, `SEL`, `LOP3`
- emitted outcome:
  - plain `P2R`
  - byte-qualified `P2R.B*`
  - no `P2R`

This normalization is enough to reveal:

- which dimensions still move closeness
- which dimensions are strip-mined
- which dimensions correlate with failure modes

## New Methods That Could Actually Break Through

These are the highest-leverage next methods.

### 1. PTX-level search

Instead of only mutating CUDA C++ source, generate PTX or NVVM IR variants
that encode predicate banks and packing structure more directly, then let
`ptxas` lower them.

Why it matters:

- if `P2R.B*` is gated by a lower-level IR shape, CUDA C++ may never expose it

### 2. Toolchain sweep

Run the strongest `B1`, `B2`, and `B3` local approximations across multiple
`nvcc` / `ptxas` versions.

Why it matters:

- the byte-qualified form may be version-gated
- a different `ptxas` may choose the form even if this one will not

### 3. Frontend sweep

Emit equivalent kernels through:

- clang CUDA
- Triton
- MLIR NVVM

Why it matters:

- the frontend IR graph may perturb `ptxas` into different form selection

### 4. Binary delta mining

Mine more library pockets around `P2R.B*` in:

- cuDNN
- cuBLAS
- TensorRT

Then compare not just opcode sets, but immediate predecessor windows and
control/dataflow motifs.

Why it matters:

- the missing rule may depend on a very local predecessor chain, not broad
  neighborhood membership

### 5. CEGIS-style constrained mutator

Use the auto-explorer as a constrained symbolic mutator that only changes the
few surviving axes:

- predicate-source kind
- pack style
- carrier lifetime
- predecessor motif

Why it matters:

- we stop wasting budget on already-falsified dimensions

### 6. Cubin surgery

If the goal shifts from source reproducibility to semantic validation, patch a
known plain `P2R` site in a `.cubin` into `P2R.B*` and validate execution.

Why it matters:

- it separates "can source trigger it?" from "what does it actually do and
  when is it legal?"

## Practical Recommendation

If we want the best chance of a real breakthrough, the next sequence should be:

1. PTX/NVVM-level search on the strongest `B1` approximation.
2. Toolchain sweep of the best `B1` and `B2` probes.
3. Library delta mining around more `P2R.B*` pockets.
4. Only then, if needed, cubin surgery for semantic validation.

That is the cleanest path out of the current source-space basin.
