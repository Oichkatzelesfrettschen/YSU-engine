# P2R Next Phase

This note scopes the post-CUDA-C++ search modes for the last direct-local
`P2R.B*` frontier.

## Immediate local facts

- local toolchain:
  - `nvcc 13.1`
  - `ptxas 13.1`
  - `clang 22.1.1`
- Python frontends available:
  - `triton 3.5.1`
  - `torch` with CUDA `13.1`
  - `onnx`
  - `onnxruntime`
- local library targets available:
  - cuDNN 9.20
  - cuBLAS 13.2
  - TensorRT 10.15 with `sm89` builder resources

## Search branches

### 1. PTX-level search

Goal:

- perturb pre-`ptxas` IR directly with `.pred`, `and.pred`, `or.pred`,
  `xor.pred`, and weighted `selp.b32` packing

Executable scaffold:

- [search_p2r_ptx.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/search_p2r_ptx.py)

First run:

- [p2r_ptx_search_20260322_215940](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_ptx_search_20260322_215940)

Initial result:

- the first direct PTX predicate-logic variants still do not emit
  `P2R.B1/B2/B3`
- they also do not emit plain `P2R`
- two of them still reproduce `PLOP3.LUT`

That means moving below CUDA C++ source is necessary, but not automatically
sufficient.

### 2. Binary delta mining

Goal:

- mine direct `P2R.B*` windows from installed cuDNN, cuBLAS, and TensorRT
  binaries rather than relying only on the older cuDNN bundle

Executable scaffold:

- [mine_library_p2r_windows.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/mine_library_p2r_windows.py)

Current live run:

- [library_p2r_windows_20260322_215940](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/library_p2r_windows_20260322_215940)

Targets:

- cuDNN precompiled engines
- cuDNN runtime-compiled engines
- cuBLAS
- TensorRT `sm89` builder resource

Current result:

- cuDNN precompiled engines are still the dominant direct source of `P2R.B*`
  windows
- cuDNN runtime-compiled engines contribute none in this sweep
- cuBLAS contributes none in this sweep
- TensorRT `sm89` builder resource is not directly `cuobjdump`-readable as
  device code
- summarized predecessor frequencies are in
  [library_p2r_window_summary_20260322_220437](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/library_p2r_window_summary_20260322_220437)
- richer motif clustering is in
  [library_p2r_motif_summary_20260322_230100](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/library_p2r_motif_summary_20260322_230100)
- the strongest new local targets are:
  - `B2`: `P2R.B2 -> R2P -> LEA/LEA.HI.X` and `P2R.B2 -> BAR.SYNC -> ULDC`
  - `B3`: `P2R.B2 -> P2R.B3 -> BAR.SYNC -> ULDC` and
    `P2R.B3 -> R2P -> LDGSTS`

### 3. Toolchain and frontend sweeps

Goal:

- test whether `P2R.B*` is frontend- or `ptxas`-version-sensitive

Immediate local feasibility:

- toolchain sweep is limited locally because only CUDA 13.1 is installed
- frontend sweep is feasible now through clang and Triton

Verified local environment:

- `nvcc 13.1`
- `ptxas 13.1`
- `clang 22.1.1`
- `triton 3.5.1`
- `torch` with CUDA `13.1`

Toolchain recommendation:

- if we add a second real `ptxas`, prefer a side-by-side CUDA `11.8` capable
  tree while keeping `/opt/cuda` `13.1` as the default
- do not bother with CUDA `10` or early `11.x` for this Ada-local frontier;
  CUDA `11.8` is the first official release with Ada support
- an archived NVIDIA HPC SDK release that can target `cuda11.8` is a cleaner
  side-by-side option than trying to downgrade the primary CUDA install

First frontend result:

- clang can emit LLVM IR and PTX for the probe bundle under
  [p2r_clang_frontend_retry_20260322_220709](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_clang_frontend_retry_20260322_220709)
- re-lowering that clang PTX through `ptxas` under
  [p2r_clang_ptxas_20260322_220720](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_clang_ptxas_20260322_220720)
  still does not emit `P2R.B*` or plain `P2R`; it collapses to dense
  `LOP3.LUT P*` / `PLOP3.LUT`

Second frontend result:

- Triton can emit a full `source -> TTIR -> TTGIR -> LLIR -> PTX -> CUBIN`
  ladder under
  [p2r_triton_search_20260322_230100](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_triton_search_20260322_230100)
- Triton still does not emit `P2R.B*` or plain `P2R`
- unlike the PTX and clang basins, Triton also avoids `PLOP3.LUT` on the
  current variants and instead lands a cleaner
  `ULDC.64 + LOP3.LUT + ISETP + SEL` family
- that makes Triton a genuinely distinct frontend basin, but not yet a
  `P2R.B*` unlock

### 4. Side-by-side PTXAS sweep

Goal:

- add a second real `ptxas` / CUDA subtree without disturbing `/opt/cuda`
  `13.1`

Current design:

- current AUR `nvhpc` packages NVIDIA HPC SDK `25.3` against a single CUDA
  `12.8` tarball
- for this frontier we want the archived `24.11` multi bundle instead, because
  it is the cleanest side-by-side path to a CUDA `11.8` capable tree while
  leaving the primary CUDA install untouched
- local sidecar package skeleton lives at
  [/home/eirikr/Github/pkgbuilds/nvhpc-sidecar-2411-multi/PKGBUILD](/home/eirikr/Github/pkgbuilds/nvhpc-sidecar-2411-multi/PKGBUILD)
- it installs under `/opt/nvidia/hpc_sdk_sidecar`
- it keeps compilers opt-in through:
  - `/opt/nvidia/nvhpc-sidecar.sh`
  - `/opt/nvidia/nvhpc-sidecar-cuda11.8.sh`
  - `/opt/nvidia/nvhpc-sidecar-cuda12.6.sh`
- download URL verified:
  `https://developer.download.nvidia.com/hpc-sdk/24.11/nvhpc_2024_2411_Linux_x86_64_cuda_multi.tar.gz`

Status:

- package metadata and `.SRCINFO` are generated
- sidecar source fetch is complete
- extracted sidecar toolchains are directly verified:
  - `ptxas 11.8.89`
  - `ptxas 12.6.77`
- first cross-version PTXAS matrix is in
  [p2r_ptxas_matrix_20260322_225854](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_ptxas_matrix_20260322_225854)
- after matching the PTX dialect to each assembler:
  - CUDA 13.1 / PTX 8.8
  - sidecar 12.6 / PTX 8.5
  - sidecar 11.8 / PTX 7.8
  the direct PTX variants still produce the same qualitative result:
  no `P2R.B*`, no plain `P2R`, and the same `PLOP3` split
- this makes the simple direct-PTX branch look version-insensitive across the
  tested `ptxas` range

Additional host-compiler control:

- a non-interfering archived GCC 13 sidecar package now lives at
  [/home/eirikr/Github/pkgbuilds/gcc13-sidecar-bin/PKGBUILD](/home/eirikr/Github/pkgbuilds/gcc13-sidecar-bin/PKGBUILD)
- it installs archived Arch `gcc13 13.3.0` binaries side-by-side and provides
  `/usr/bin/g++-13`
- helper env script:
  `/opt/gcc13-sidecar/gcc13-sidecar.sh`
- this is enough to remove GCC 15/14 as the blocker for older sidecar `nvcc`
  lanes
- but it does not fully unlock cross-version `nvcc -G`, because the remaining
  failures are now newer glibc header compatibility, not host compiler
  selection

Cross-version `nvcc -G` retry:

- rerun is at
  [p2r_nvcc_debug_matrix_20260322_232226](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_nvcc_debug_matrix_20260322_232226)
- CUDA 13.1 remains the only meaningful debug lane locally
- sidecar 11.8 with `g++-13` still fails on `_Float32/_Float64` glibc header
  parsing and math declaration drift
- sidecar 12.6 with `g++-13` still fails on glibc math declaration drift
- so a true older-`nvcc` debug sweep now wants an older glibc/sysroot or a
  containerized older distro, not just an older GCC

Exact motif rerun:

- stricter `B2/B3` motif reruns are now complete across all three `ptxas`
  generations:
  - `B2 -> R2P -> LEA -> LEA.HI.X` approximation
  - `B3 -> BAR.SYNC -> IADD3 -> R2P` approximation
- release results stay version-invariant across CUDA 13.1, sidecar 12.6, and
  sidecar 11.8:
  - no `P2R.B*`
  - no plain `P2R`
  - no `R2P`
  - but stable recovery of `BAR.SYNC`, `ULDC`, and `LDS` in the richer `B3`
    shapes
- this further sharpens the binary-side RCA: even when we reproduce more of the
  cuDNN `B2/B3` neighborhood, the byte-qualified `P2R`/`R2P` form selection
  still does not unlock from standalone PTX
### 5. CEGIS-style mutator

Goal:

- constrain search to surviving axes only:
  - target byte
  - predicate-source kind
  - carrier lifetime
  - predecessor motif

Current phase-3 tooling:

- step scope:
  [NEXT120_P2R_PHASE3.md](/home/eirikr/Github/YSU-engine/src/sass_re/NEXT120_P2R_PHASE3.md)
- seed extractor:
  [extract_p2r_motif_seeds.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/extract_p2r_motif_seeds.py)
- constrained mutator:
  [search_p2r_ptx_cegis.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/search_p2r_ptx_cegis.py)
- patchpoint inspector:
  [inspect_cubin_p2r_patchpoints.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/inspect_cubin_p2r_patchpoints.py)
- semantic shortlist planner:
  [plan_p2r_cubin_semantic_patch.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/plan_p2r_cubin_semantic_patch.py)

Executed results:

- extracted seeds:
  [p2r_motif_seeds_20260322_233001](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_motif_seeds_20260322_233001)
- top exact classes are now explicit:
  - dominant `B2`: `ISETP.GE -> P2R.B2 -> LDS.64`
  - rich `B2`: `ISETP.GE -> P2R.B2 -> R2P -> LEA/LEA.HI.X`
  - rich `B2`: `ISETP.LT -> P2R.B2 -> BAR.SYNC`
  - rich `B3`: `ISETP.LT -> P2R.B3 -> BAR.SYNC`
  - rich `B3`: `ISETP.GE -> P2R.B3 -> R2P -> LEA/LEA.HI.X`
- constrained mutator runs are now complete across all three `ptxas`
  generations:
  - CUDA 13.1
  - sidecar 12.6
  - sidecar 11.8
- first seeded runs confirm the old result on the dominant class:
  they recover `ULDC`, but still no `P2R.B*` or `R2P`
- unique-class seeded runs sharpen the same conclusion on the richer branches:
  even `R2P/LEA`-class and `BAR.SYNC`-class seeds remain version-invariant and
  still do not select `P2R.B*` or `R2P`
- the best local patchpoints are now ranked in
  [p2r_patchpoints_dedup_20260322_233108](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_patchpoints_dedup_20260322_233108)
- the first semantic patch shortlist is in
  [p2r_cubin_semantic_patch_20260322_233138](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_semantic_patch_20260322_233138)
- that shortlist currently leans toward `B3` as the best first semantic patch
  target on the strongest local plain-`P2R` sites

### 6. Cubin surgery

Goal:

- validate semantics of `P2R.B*` even if source reproducibility remains closed

Current status:

- semantic validation is now the best remaining move
- source-space, direct PTX, frontend variation, and simple version sweeps have
  all converged on the same boundary
- the next practical escalation is to operate on the shortlisted local
  plain-`P2R` cubins and test whether `B3`-leaning substitutions remain
  structurally and semantically stable

First cubin-side breakthrough:

- the top local plain-`P2R 0x7f` site in
  [probe_p2r_two_stage_bank_exact_O3.cubin](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_symbolic_matrix_20260322_194108/probe_p2r_two_stage_bank_exact_O3.cubin)
  is unique and patchable
- replacing its 128-bit instruction pair with the derived `B2` and `B3` pairs
  yields real re-disassembly as:
  - `P2R.B2 R0, PR, R0, 0x78`
  - `P2R.B3 R0, PR, R0, 0x78`
- patch-trial artifacts:
  [p2r_cubin_patch_trial_20260322_233700](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_patch_trial_20260322_233700)
- the derived patch sketches are in
  [p2r_patch_sketches_20260322_233503](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_patch_sketches_20260322_233503)
- the control-half validation is in
  [p2r_patch_validation_20260322_233549](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_patch_validation_20260322_233549)

First runtime split:

- patched `two_stage` cubins are runtime-stable under the driver harness and
  match the sampled baseline outputs:
  [p2r_cubin_runtime_trial_20260322_233706](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_runtime_trial_20260322_233706)
- patched `byteview` cubins re-disassemble correctly, but the guarded launch
  path does not complete within the timeout budget:
  [p2r_cubin_runtime_trial_byteview_guarded_20260322_233856](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_runtime_trial_byteview_guarded_20260322_233856)
- that is the current best semantic boundary:
  some local plain-`P2R` sites tolerate byte-lane substitution, others do not

Second semantic-validation tranche:

- reusable cubin patch and matrix tooling now exists:
  - [patch_p2r_cubin.py](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/patch_p2r_cubin.py)
  - [validate_p2r_cubin_pattern_matrix.sh](/home/eirikr/Github/YSU-engine/src/sass_re/scripts/validate_p2r_cubin_pattern_matrix.sh)
- the multi-pattern `two_stage` matrix is now in
  [p2r_cubin_pattern_matrix_20260322_234513](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_pattern_matrix_20260322_234513)
- that sharper matrix overturns the earlier overly-optimistic single-pattern
  read:
  - `P2R.B2` and `P2R.B3` substitutions both execute cleanly
  - patterns `0` and `1` are semantically inert versus baseline
  - patterns `2` and `3` are not inert
  - `B2` and `B3` collapse to the same result on pattern `2`
  - `B2` and `B3` diverge from each other on pattern `3`
- so `probe_p2r_two_stage_bank_exact` is now best described as:
  structurally patchable, runtime-stable, but only conditionally
  semantics-preserving

Sibling-candidate expansion:

- a unique `B2`-leaning site inside the same cubin family,
  `probe_p2r_b2_nibble_exact`, now has direct local patched disassembly as
  `P2R.B2 R6, PR, R0, 0x78` and `P2R.B3 R6, PR, R0, 0x78` under
  [p2r_semantic_expansion_20260322_234457](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_semantic_expansion_20260322_234457)
- its runtime matrix is in
  [p2r_cubin_pattern_matrix_20260322_234517](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_pattern_matrix_20260322_234517)
- that site is runtime-stable on all tested patterns
  - patterns `0`, `1`, and `3` deterministically differ from baseline
  - pattern `2` matches baseline
  - `B2` and `B3` are semantically identical to each other on all four tested
    patterns
- a unique `B3`-leaning site, `probe_p2r_b3_nibble_transition_exact`, now has
  direct local patched disassembly as `P2R.B2 R3, PR, R0, 0x78` and
  `P2R.B3 R3, PR, R0, 0x78` in the same expansion bundle
- its runtime matrix is in
  [p2r_cubin_pattern_matrix_20260322_234522](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_pattern_matrix_20260322_234522)
- that site is also runtime-stable on all tested patterns
  - all four tested patterns differ from baseline
  - `B2` and `B3` differ from each other on patterns `0`, `1`, and `2`
  - `B2` and `B3` collapse to the same result on pattern `3`

Occurrence-targeted tripack follow-up:

- non-unique patching is now demonstrated too: the second occurrence of the
  `R2 <- R2, 0xf` pair in the shared cubin was patched in-place for
  `probe_p2r_b2_tripack_prefix_exact`
- patched disassembly is in the same semantic expansion bundle, and the
  runtime matrix is
  [p2r_cubin_pattern_matrix_20260322_234632](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_pattern_matrix_20260322_234632)
- this higher-scoring multi-`P2R` context is runtime-stable on all four tested
  patterns, but differs from baseline on all four
- `B2` and `B3` again collapse to the same observed outputs on all four tested
  patterns

Updated semantic boundary:

- direct local optimized source/IR still does not emit `P2R.B1/B2/B3`
- cubin-side patching can now materialize direct local `P2R.B1/B2/B3`
- semantic outcomes fall into three classes:
  - inert on some patterns: `two_stage`
  - stable but deterministically different: `b2_nibble_exact`,
    `b3_nibble_transition_exact`, `b2_tripack_prefix_exact`
  - unstable / non-terminating: `byteview`
- the real remaining unknown is no longer whether local code can carry
  byte-qualified `P2R`; it can after cubin-side substitution.
  The remaining question is which local contexts preserve semantics, and why.

`B1` completion:

- the same `two_stage` top site now also patches cleanly to
  `P2R.B1 R0, PR, R0, 0x78` under the semantic expansion bundle
- its multi-pattern matrix is in
  [p2r_cubin_pattern_matrix_20260322_235427](/home/eirikr/Github/YSU-engine/src/sass_re/results/runs/p2r_cubin_pattern_matrix_20260322_235427)
- `B1` follows the same high-level shape as the earlier `B2/B3` two-stage
  substitutions:
  - patterns `0` and `1` are inert
  - patterns `2` and `3` differ from baseline
- that closes the cubin-side materialization gap for the full byte-qualified
  `P2R.B1/B2/B3` family
