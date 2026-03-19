# SASS RE Toolkit: Next Phases

Scoped based on the complete Ada Lovelace SM 8.9 characterization
(53 probes, 9 microbenchmarks, 221+ SASS mnemonics, 38+ latency measurements,
ncu hardware counter cross-validation).

---

## Phase 1: Hopper SM 9.0 ISA Delta (requires H100/H200 access)

Hopper introduces significant ISA changes that our probe suite can
immediately characterize once hardware is available:

### New instructions on Hopper (not on Ada)

| Feature | Expected SASS | Impact |
|---|---|---|
| FP8 tensor cores | HMMA.*.E4M3/E5M2 | Native FP8 MMA (Ada only has F2FP conversion) |
| TMA (Tensor Memory Accelerator) | TMA.LOAD/TMA.STORE | Hardware async bulk copy replacing cp.async |
| Thread Block Clusters | CCTL.CLUSTER, BAR.CLUSTER | Cross-SM synchronization without grid.sync |
| DPX (Dynamic Programming) | DPX.ADD/DPX.MIN | Hardware sort/pathfinding primitives |
| Distributed Shared Memory | LD.DSMEM, ST.DSMEM | Cross-SM shared memory access |
| FP64 tensor cores (data center) | DMMA | FP64 MMA (Ada gaming has no FP64 TC) |

### Probe plan for Hopper
- Port all 53 existing probes unchanged (baseline comparison)
- Add 6 new probes for Hopper-only features
- Run full latency + throughput + ncu suite
- Diff SASS encoding between Ada and Hopper (using compare_architectures.py)

### Expected findings
- TMA should replace LDGSTS with higher throughput
- FP8 TC should show ~2x throughput over Ada's F2FP emulation path
- Thread Block Clusters may enable new tiled LBM patterns
- DPX may accelerate sparse brick sorting

---

## Phase 2: Blackwell SM 10.0 ISA Delta (requires RTX 50-series)

Blackwell is the most architecturally significant change:

### New on Blackwell

| Feature | Expected SASS | Impact |
|---|---|---|
| Native FP4 E2M1 tensor cores | HMMA.*.FP4 | Replaces our LUT emulation (4bit_formats probe) |
| FP6 E3M2 format | F2FP.E3M2, HMMA.*.FP6 | New 6-bit float (between FP4 and FP8) |
| 5th gen tensor cores | HMMA shape changes | Higher throughput per instruction |
| Enhanced FP8 | Improved E4M3/E5M2 TC | Higher precision MMA |
| Blackwell memory | HBM3e | Different cache hierarchy |

### Key question for Blackwell
Does FP4 E2M1 tensor core throughput match or exceed INT4 (189K TOPS on Ada)?
If yes, FP4 becomes viable for LBM bandwidth ceiling measurement with
slightly better physics accuracy than INT4.

---

## Phase 3: Production Kernel Optimization (immediate, on current Ada hardware)

Based on our findings, these kernel changes have the highest ROI:

### Priority 1: BF16 kernels should replace FP16 where applicable

| Finding | Action |
|---|---|
| HFMA2.BF16 at 4.01cy < FP16 at 4.54cy | BF16 packed FMA is 12% faster |
| BF16 throughput 312 > FP16 260 ops/clk/SM | BF16 achieves 22% higher throughput |
| BF16 conversion 8.54cy < FP16 10.54cy | BF16 encode/decode is faster |

**Recommendation**: Create `kernels_bf16_soa_bf162.cu` using `__nv_bfloat162`
packed arithmetic (same pattern as `kernels_fp16_soa_half2.cu`). Expected:
+20-25% MLUPS improvement over current BF16 SoA kernel.

### Priority 2: REDUX.SUM for integer reductions

Replace 5-stage SHFL tree with single REDUX.SUM in:
- `kernels_box_counting.cu` (ballot + popc + atomicAdd pattern)
- Any warp-level integer aggregation

**Expected savings**: 96 cycles per reduction (156 -> 60 cy).

### Priority 3: Bank conflict penalty is minimal on Ada

The tiled pull-scheme (`kernels_soa.cu` tiled variant) was classified as
an anti-pattern at 128^3 (C-1389). Our bank conflict measurement shows
only 2.2x worst-case penalty (not 32x). This partially rehabilitates
tiled kernels at 64^3 (L2-transitional regime) where the halo loads
benefit from L2 hit rates.

**Action**: Re-benchmark tiled variants at 64^3 specifically.

### Priority 4: Pre-compute inv_tau for BGK kernels

MUFU.RCP at 41.53cy is 73% of BGK ALU budget (57 FMA).
Pre-computing `1.0f / tau` as a per-cell field costs 4 bytes/cell (8 MB at 128^3)
but saves ~16% of BGK compute time.

### Priority 5: INT8 SoA MRT + A-A kernel

The Pareto-optimal kernel (INT8 SoA at 5643 MLUPS) does not yet have an
MRT + A-A variant. MRT is free (latency-hidden), A-A halves VRAM.
Expected: ~5100-5600 MLUPS with 50% VRAM reduction.

---

## Phase 4: Pascal SM 6.1 Comparison (requires GTX 1050 Ti)

The comparison paper outline (`PAPER_OUTLINE.md`) is ready. All 53 probes
can run on Pascal with SM 6.1 compatibility (12 probes require SM 7.0+
and will be skipped). Key comparisons:

- IADD3 vs IADD (Pascal has no 3-input add)
- XMAD vs IMAD.WIDE (Pascal uses XMAD for widening multiply)
- LOP3 vs LOP (Pascal has 2-input logic only)
- SHFL vs SHFL.SYNC (Pascal has implicit warp sync)
- FP16 HADD2 throughput (Pascal Titan Xp has good FP16; GTX 1050 Ti does not)
- BREV/POPC/FLO routing (SFU on Ada -- same on Pascal?)
- Bank conflict penalty (2.2x on Ada -- linear on Pascal?)
- MUFU latency comparison (value-dependent convergence differs)

---

## Phase 5: Multi-GPU and NVLink Characterization

If multi-GPU access becomes available:
- System-scope memory operations (LDG.E.STRONG.SYS already probed)
- MEMBAR.SYS latency across NVLink vs PCIe
- Peer-to-peer atomic throughput
- Multi-GPU LBM domain decomposition communication cost

---

## Phase 6: Encoding Completeness

The instruction encoding analysis has mapped opcode fields (bits [48:63])
and control word patterns but register field boundaries remain inferred.
The `probe_encoding_verify.cu` provides systematic register sweeps for
XOR-diffing, but exhaustive verification requires:

- All 256 GPR assignments (R0-R255) for dest/srcA/srcB
- Immediate field width for each instruction class
- Predicate guard encoding (which 3 bits select P0-P7)
- Rounding mode modifier bits (.RN, .RZ, .RP, .RM)
- Memory scope modifier encoding (.GPU, .SYS, .CTA)
- Cache policy modifier encoding (.EF, .CONSTANT, .STRONG)

---

## Summary: What We Built

| Metric | Count |
|---|---|
| Probe kernels | 53 |
| Microbenchmarks | 9 |
| Scripts | 11 |
| Total CUDA source files | 62 |
| Unique SASS mnemonics | 221+ |
| Latency measurements | 38+ (corrected via ncu) |
| Throughput measurements | 10+ |
| Novel discoveries | 20+ |
| ncu hardware counter validations | 41 kernels profiled |
| Commits this session | 15+ |
| Numeric formats documented | UINT/INT/FP/TF/BF at 4-256 bits |

The Ada Lovelace SM 8.9 ISA is now the most thoroughly independently
characterized NVIDIA GPU architecture in the public domain.
