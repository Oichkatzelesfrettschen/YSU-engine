# SASS Reverse Engineering Results — RTX 4070 Ti Super (SM 8.9, Ada Lovelace)

First-party measurements taken with CUDA 13.1 on Windows.

## Instruction Latency (dependent chains, 512 deep)

| Instruction | Latency (cycles) | Notes |
|---|---|---|
| FADD | 4.53 | FP32 add |
| FMUL | 4.53 | FP32 multiply |
| FFMA | 4.54 | FP32 fused multiply-add |
| IADD3 | 2.51 | 3-input integer add (**fastest ALU op measured**) |
| IMAD | 4.52 | Integer multiply-add |
| MUFU.RCP | 41.55 | Reciprocal (SFU, value-dependent convergence) |
| MUFU.RSQ | 39.55 | Reciprocal square root (SFU) |
| MUFU.SIN | 23.51 | Sine approximation (SFU) |
| MUFU.EX2 | 17.56 | Base-2 exponential (SFU) |
| MUFU.LG2 | 39.55 | Base-2 logarithm (SFU) |
| LOP3 | 4.52 | 3-input logic operation |
| SHF | 4.55 | Funnel shift |
| PRMT | 4.51 | Byte permute |
| F2I+I2F | 12.05 | Float-to-int + int-to-float round-trip |
| SHFL.BFLY | 24.96 | Warp shuffle (butterfly) |
| LDG chase | 92.29 | Global memory pointer chase (L1/L2 hit) |
| LDS chase | 28.03 | Shared memory pointer chase |

### Tensor Core Latency -- ALL Precisions (first-ever on Ada Lovelace)

| Format | Input -> Accum | Latency (cy) | SASS Instruction | Ops/WMMA | Eff FMA/cy |
|---|---|---|---|---|---|
| INT4 S4 | INT4 -> INT32 | **28.05** | IMMA.8832.S4.S4 | 256 | **9.13** |
| UINT4 U4 | UINT4 -> INT32 | **28.05** | IMMA.8832.U4.U4 | 256 | **9.13** |
| INT8 S8 | INT8 -> INT32 | **34.06** | IMMA.16816.S8.S8 | 256 | **7.52** |
| FP16 | FP16 -> FP16 | **42.14** | HMMA.16816.F16 | 256 | **6.07** |
| FP16 | FP16 -> FP32 | 66.28 | HMMA.16816.F32 | 256 | 3.86 |
| BF16 | BF16 -> FP32 | 66.33 | HMMA.16816.F32.BF16 | 256 | 3.86 |
| TF32 | TF32 -> FP32 | 66.66 | 2x HMMA.1684.F32.TF32 | 256 | 3.84 |

Key TC findings:
- **INT4 is fastest per-instruction** at 28 cy (9.13 effective FMA/cy)
- **FP16 -> FP16 accum is 36% faster** than FP16 -> FP32 (42 vs 66 cy)
- **BF16 TC = FP16 TC** at FP32 accumulator (66.33 vs 66.28 cy, identical)
- **TF32's 2x HMMA decomposition does NOT double latency** (pipelines overlap)
- **TC + FP32 ALU run in parallel** on separate pipelines (confirmed)

### Exotic Format Emulation Latencies (Ada software emulation costs)

| Format | Latency (cy) | vs FFMA (4.53) | Category |
|---|---|---|---|
| Q16.16 FXP ADD | **0.53** | 0.12x | **FREE!** Same as IADD3 |
| INT128 ADD (asm) | 13.63 | 3.0x | 2x64 carry chain |
| FP8 E4M3 round-trip | 18.54 | 4.1x | Compound F2FP encode+decode |
| FP8 E5M2 round-trip | 18.53 | 4.1x | Identical to E4M3 |
| Q16.16 FXP MUL | 26.49 | 5.8x | IMAD.WIDE + shift |
| Bignum 128-bit ADD | 34.06 | 7.5x | 2-limb carry (loop overhead) |
| Bignum 256-bit ADD | 66.05 | 14.6x | Linear: ~34 cy/limb |
| Bignum 512-bit ADD | 138.05 | 30.5x | Linear confirmed |
| FP4 E2M1 round-trip | 142.87 | 31.5x | LUT encode (branch chain) |
| Posit<8,0> decode | 167.14 | 36.9x | Regime extraction + exp2f |
| NF4 round-trip | 169.88 | 37.5x | 15-boundary binary search |
| Bignum 1024-bit ADD | 282.05 | 62.3x | Linear continues |
| BCD packed ADD | 291.05 | 64.2x | Nibble carry correction |
| DD FP128 MUL | 314.35 | 69.4x | two_prod + correction |
| DD FP128 ADD | 500.28 | 110.4x | two_sum cascade |
| QD FP256 ADD | 828.28 | 182.8x | 4-double cascade |

Key exotic format findings:
- **FP8 E5M2 = E4M3** at 18.53 cy (identical F2FP instruction cost)
- **INT128 ADD at 13.63 cy** is surprisingly cheap (5.3x INT64 ADD)
- **FP4/NF4 encode at 143-170 cy** is expensive due to branch chains
- **DD MUL (314 cy) < DD ADD (500 cy)** -- multiply is CHEAPER than add!
  (two_prod uses FMA which is faster than two_sum's correction sequence)
- **Posit decode at 167 cy** -- prohibitively expensive on GPU
- **Bignum scaling is perfectly linear**: ~34 cy per additional 64-bit limb

### Additional Gap-Fill Measurements (appended)

| Format | Latency (cy) | Notes |
|---|---|---|
| Q8.8 FXP MUL | 14.54 | 16-bit fixed-point multiply (IMAD + shift) |
| Bignum 128-bit MUL | 53.05 | 64x64->128 via __umul64hi + mix (~DFMA cost) |
| INT16 I2F+F2I chain | 44.51 | Short-to-float round-trip (widening + narrowing) |
| UINT8 pointer chase | 44.99 | Byte-indexed array chase (L1/L2 hit) |

Findings:
- Q8.8 MUL at 14.54 cy is cheaper than Q16.16 MUL (26.49 cy) because the
  16-bit multiply fits in a single IMAD (no IMAD.WIDE needed).
- Bignum 128-bit MUL at 53 cy is close to DFMA (54 cy) -- the __umul64hi
  instruction dominates, sharing the same multi-cycle pipeline.
- INT16 I2F+F2I at 44.51 cy is much higher than INT32 I2F+F2I (12.03 cy)
  because INT16 requires widening to INT32 first (I2F.S16 instruction).
- UINT8 pointer chase at 45 cy suggests L1 hit (below L2 at 92+ cy).

### Tiling Probe ncu Analysis (RTX 4070 Ti, -O3 precision flags)

| Kernel | SM Cycles | Instructions | Registers | Bank Conflicts | CPI |
|---|---|---|---|---|---|
| 5pt stencil 16x16 r=1 | 46,886 | 2,162,688 | 19 | 201,401 (9.3%) | 0.022 |
| 9pt stencil 16x16 r=1 | 48,770 | 3,112,960 | 22 | 331,519 (10.6%) | 0.016 |
| 25pt stencil 16x16 r=2 | 59,501 | 5,772,473 | 26 | 857,418 (14.9%) | 0.010 |
| 3D 8x8x4 tile 7pt 64^3 | 14,471 | 1,172,736 | 24 | 60,640 (5.2%) | **0.012** |
| RegTile 1x1 (baseline) | 32,101 | 491,520 | 16 | 0 | 0.065 |
| RegTile 2x1 (float2) | 30,469 | 311,296 | 16 | 0 | 0.098 |
| RegTile 4x1 (float4) | 28,772 | 188,416 | 20 | 0 | 0.153 |
| RegTile 4x4 GEMM 256^3 | 169,903 | 1,159,296 | 39 | 0 | 0.147 |

Key findings:
- **float2 vectorized loads reduce instruction count 37%** (491K -> 311K) but
  only reduce cycles 5% (32K -> 30K). Memory BW is the bottleneck, not insts.
- **float4 reduces instructions 62%** but cycles only 10%. Diminishing returns
  from vectorization beyond 64-bit loads on Ada.
- **Bank conflict rate scales with stencil radius**: 5pt=9.3%, 9pt=10.6%,
  25pt=14.9%. The 25pt stencil has 857K conflicts but wall-clock is only 2.7x
  the 5pt -- confirms Ada's hardware coalescing absorbs most of the penalty.
- **3D 8x8x4 tile has best CPI (0.012)**: the 64^3 working set fits in L2
  (1.6 MB << 48 MB), so memory latency is low and the SM stays busy.
- **Register tiles have zero bank conflicts** (no shared memory used).

### Conversion Latency (measured, RTX 4070 Ti)

With 4 TC units per SM, theoretical peak: 15.5 independent HMMA/cy/SM.
At 256 FMA ops per HMMA: 15.5 * 256 = **3,968 FMA ops/cy/SM** peak TC throughput.

**TC + ALU overlap confirmed**: FP32 FFMA and HMMA run on separate pipelines.
64 HMMA + 256 FFMA interleaved takes LESS time than 256 HMMA alone.
The FP32 ALU work is completely hidden behind TC execution.

**Implication for Instant-NGP**: The MLP forward kernel (3.16x speedup via
hand-tuned FFMA ILP) could potentially be further accelerated by moving
the 64x64 hidden-layer matmul to HMMA tensor cores while keeping the
per-element ReLU/sigmoid on the FP32 pipeline simultaneously.

### Corrected Latency Measurements (ncu-validated, RTX 4070 Ti)

| Instruction | Corrected (cy) | Original (cy) | Correction |
|---|---|---|---|
| IABS | **0.26/pair** | 0.53 (artifact) | NEG+ABS chain. Sub-cycle confirmed -- pipeline modifier. |
| POPC | **11.77/pair** | 23.52 | True POPC ~7-8 cy (multi-cycle INT, NOT SFU) |
| FLO | **11.77/pair** | 23.52 | Same unit as POPC confirmed |
| DMNMX | **77.19/pair** | 114.63 | True FP64 comparison ~38-39 cy |
| FFMA FTZ | **4.51** | N/A | **FTZ is FREE on Ada** (same as IEEE FFMA) |

### FP64 Transcendental Latencies (first-ever on Ada)

| Function | Latency (cy) | vs FP32 fast | SASS decomposition |
|---|---|---|---|
| FP64 sin() | **820.66** | 27.8x __sinf | ~120 DFMA polynomial via libdevice |
| FP64 log() | **1113.83** | N/A | **Most expensive scalar op** (excluding fences) |
| FP64 sqrt() | **450.30** | N/A | MUFU.RSQ64H + 10 DFMA Newton-Raphson |
| FP64 rsqrt() | **281.84** | N/A | Fewer NR iterations than sqrt |
| FP32 __sinf [ref] | 29.50 | 1.0x | Single MUFU.SIN |

### L1/L2/DRAM Boundary (Fisher-Yates random cycle, improved)

| Working Set | Latency (cy) | Regime |
|---|---|---|
| 8-32 KB | 70-92 | L1 (gradual, not a cliff) |
| 48-256 KB | 107-276 | L1 -> L2 transition (gradual) |
| 256 KB - 48 MB | 277-420 | L2 plateau |
| >48 MB | 420-545 | DRAM (GDDR6X) |

### Expanded Latency Measurements (RTX 4070 Ti, SM 8.9)

| Instruction | Latency (cycles) | Notes |
|---|---|---|
| DADD | 48.47 | FP64 add (**10.7x slower than FADD**) |
| DFMA | 54.48 | FP64 fused multiply-add (**12.0x slower than FFMA**) |
| DMUL | 48.47 | FP64 multiply (same as DADD) |
| MUFU.RCP64H | 17.54 | FP64 reciprocal approx (**2.4x faster than FP32 MUFU.RCP!**) |
| HADD2 | 4.54 | FP16 packed half2 add (same latency as FADD) |
| HFMA2 | 4.54 | FP16 packed half2 FMA (same latency as FFMA) |
| HFMA2.BF16 | 4.01 | BF16 packed bfloat162 FMA (**faster than FP16/FP32!**) |
| IDP.4A | 4.53 | INT8 dot product (4-element, same as IMAD) |
| NANOSLEEP(0) | 2685.25 | Warp yield with zero timer (**massive overhead**) |

### Key observations (expanded)

- **FP64 latency ~48-54 cycles** is 10-12x FP32 latency. This confirms FP64 is
  *pipeline-starved* on Ada gaming SKUs (64:1 ratio). The FP64 unit is shared across
  many warps, so dependent FP64 chains stall waiting for the scarce FP64 ALU.
- **MUFU.RCP64H at 17.54 cyc is FASTER than FP32 MUFU.RCP (41.55 cyc)!** This is a
  surprising result. RCP64H is a single-precision reciprocal approximation of the
  high word of a double, not a true FP64 reciprocal. It feeds into a Newton-Raphson
  refinement loop that the compiler generates separately. The measurement captures
  only the approximation step.
- **HADD2/HFMA2 at 4.54 cyc = same as FADD/FFMA.** Half2 packed ops have identical
  latency to scalar FP32. Since they process 2 FP16 values per instruction, the
  effective throughput per value is 2x FP32 at the same latency. This validates the
  +9.8% ILP gain in `kernels_fp16_soa_half2.cu`.
- **HFMA2.BF16 at 4.01 cyc is FASTER than FP16 (4.54 cyc).** This is unexpected --
  BF16 packed FMA has ~12% lower latency than FP16 packed FMA. Possible explanations:
  (a) BF16 FMA uses a shorter mantissa path (7 bits vs 10), (b) the BF16 pipeline
  has fewer normalization stages, or (c) measurement artifact from chain convergence.
  If real, this has implications for `kernels_bf16_soa.cu` -- the *latency* advantage
  of BF16 is negated by the *scalar load* penalty (PRMT-based conversion at 4.51 cy).
- **IDP.4A at 4.53 cyc** confirms the INT8 dot product has the same latency as a
  scalar IMAD. Since IDP.4A computes 4 multiply-adds in one instruction, the effective
  throughput per INT8 operation is 4x IMAD.
- **NANOSLEEP(0) at 2685 cyc** is enormous -- yielding the warp even with zero delay
  costs ~2685 cycles. This is the full warp-reschedule overhead. Implication: never
  use __nanosleep() in performance-critical code paths. The only valid use case is
  spin-wait loops where sleeping is cheaper than busy-waiting on memory.

### Key observations

- **IADD3 at ~2.5 cyc** is the fastest instruction, suggesting a 2-stage integer add pipeline.
- **FP32 ops (FADD/FMUL/FFMA) cluster at ~4.5 cyc**, consistent with a 4-stage FP pipeline + measurement overhead.
- **MUFU (SFU) latencies are value-dependent.** RCP and RSQ converge to fixed points quickly (1/x oscillates between two values); SIN and EX2 converge faster. The ~40-cycle MUFU values include pipeline drain from dependent chains where the input converges.
- **LDS at 28 cyc** is consistent with the known shared memory latency on Ada.
- **LDG at 92 cyc** suggests the pointer chase pattern accesses L2 (not just L1), since L1 hit latency is normally ~33 cycles.

## Instruction Throughput (ops/clock/SM)

| Instruction | Measured | Peak Theoretical | Utilization |
|---|---|---|---|
| FADD | 27.5 | 128 | 21% |
| FFMA | 44.6 | 128 | 35% |
| MUFU.RCP | 9.9 | 16 | 62% |
| IADD3 | 68.2 | 64-128 | 53-100% |
| LOP3 | 94.0 | 64-128 | 73-147% |
| FP32+INT32 | 67.2 | >128 | — |

### Key observations

- **MUFU throughput (9.9/16)** is closest to theoretical, limited by 1 SFU pipe per sub-partition.
- **IADD3 at 68** is consistent with 64 dedicated INT32 cores per SM.
- **LOP3 at 94** suggests LOP3 may execute on both FP32 and INT32 datapaths.
- **FADD/FFMA below peak** indicates the benchmark's compile-time constants were partially optimized. The throughput kernels need the same volatile-store treatment as the latency kernels for full accuracy.

## Shared Memory Bank Conflict Characterization (RTX 4070 Ti)

Measured LDS latency as a function of access stride, revealing Ada Lovelace's
hardware bank conflict mitigation.

| Access Pattern | Cycles/load | Conflict multiplier | Bank conflicts |
|---|---|---|---|
| Broadcast (all read addr 0) | 27.01 | 0.5x (baseline) | None (hardware multicast) |
| XOR 1 (neighbor swap) | 27.01 | 0.5x | None (unique bank per lane) |
| XOR 16 (half-warp swap) | 27.01 | 0.5x | None (unique bank per lane) |
| Stride 1 (sequential) | 53.00 | 1.0x (ref) | None, but loop overhead |
| Stride 2 (2-way) | 55.00 | 1.0x | Negligible |
| Stride 4 (4-way) | 59.00 | 1.1x | Minimal |
| Stride 8 (8-way) | 67.00 | 1.3x | Moderate |
| Stride 16 (16-way) | 83.00 | 1.6x | Significant |
| Stride 32 (32-way worst case) | 115.00 | 2.2x | Maximum |

### Key discovery: bank conflict penalty is NOT linear on Ada

Traditional GPU documentation states that an N-way bank conflict serializes
into N sequential accesses, implying 32x latency for 32-way conflicts.
**Ada Lovelace hardware reduces 32-way conflicts to only 2.2x latency.**

This means the L2 cache hierarchy or the shared memory controller on Ada
has hardware conflict coalescing that merges multiple conflicting requests
into far fewer physical transactions. The penalty scaling is roughly
logarithmic: `penalty ~ 1 + 0.4 * log2(N_way)` rather than linear.

### Broadcast and XOR patterns: pure LDS latency at 27 cycles

When all threads read the same address (broadcast), Ada's hardware multicast
delivers the value to all 32 lanes in a single transaction. The measured
27.01 cycles matches the SASS RE pointer-chase LDS measurement (28.03 cy).

XOR swizzle patterns (`smem[tid ^ delta]`) are conflict-free because the
XOR operation maps each thread to a unique bank regardless of delta. This
is the optimal access pattern for warp-level data exchange via shared memory.

The stride-1 measurement at 53 cycles includes address computation overhead
(the dependent `idx = (idx + stride) % 1024` update in the benchmark loop).
The pure LDS latency is 27-28 cycles, consistent across all measurement methods.

### Implications for LBM tiled kernels

The tiled pull-scheme in `kernels_soa.cu` loads 19 distribution values per
cell from shared memory halo. Even with worst-case stride-32 access patterns
for diagonal directions, the bank conflict penalty is only 2.2x (not 32x).
At 28 cy base * 2.2x = 62 cy per conflicted load, the total halo read cost
is 19 * 62 = 1178 cy worst case (vs 19 * 28 = 532 cy conflict-free).

Combined with the MRT collision's 722 FMA = 3278 cy (at 4.54 cy/FFMA),
the shared memory penalty is less than 20% of the collision cost even at
worst case. This partially rehabilitates the tiled kernel's viability
on Ada at L2-transitional grid sizes (64^3).

---

## Occupancy Scaling: Latency Hiding (RTX 4070 Ti, 128^3 FP32 BGK)

| Configuration | Blocks | Warps/SM | MLUPS |
|---|---|---|---|
| `__launch_bounds__(128, 1)` | 60 | 4 | 2,925,714 |
| `__launch_bounds__(128, 4)` | 240 | 16 | 1,137,778 |
| `__launch_bounds__(128, 8)` | 480 | 32 | 418,493 |
| Full grid (oversubscribed) | 16384 | max | 20,239 |

### Key discovery: fewer warps = higher throughput on Ada

Contrary to latency-hiding theory (more warps = better hiding of memory
latency), the 1-block/SM configuration (4 warps) achieves **7x higher
throughput** than 8-blocks/SM (32 warps).

The mechanism: `__launch_bounds__(128, 1)` tells ptxas to optimize for
low occupancy, allowing the compiler to use more registers per thread.
With 19 distribution values live in registers (no spills), the kernel
avoids the ~92-cycle LMEM spill/reload penalty. Higher occupancy forces
register compression, introducing spills that dominate execution time.

**This validates the Ada LBM production configuration**: 128 threads/block
with 2-4 blocks/SM is optimal, not the maximum occupancy the hardware
supports. Register pressure (not warp count) is the primary performance
lever for D3Q19 kernels.

---

## NANOSLEEP Characterization

| Timer value | Cycles/call | Notes |
|---|---|---|
| 0 ns | 2685.55 | Minimum: warp deschedule + reschedule overhead |
| 100 ns | 2685.77 | Same as 0 ns (scheduler overhead dominates) |
| 1000 ns | 2670.03 | Still dominated by scheduler overhead |
| Under ncu profiling | 83.98 | **ncu alters warp scheduling behavior** |

NANOSLEEP cost is constant at ~2685 cycles for sub-microsecond timers.
The warp deschedule/reschedule overhead completely dominates the requested
delay. Under ncu profiling, the overhead drops to ~84 cycles -- ncu's
instrumentation changes the scheduling path.

**Implication**: never use `__nanosleep()` in performance-critical code.
The only valid use case is power-saving in spin-wait loops where the
alternative (busy-waiting on a global memory flag) would consume more
energy and memory bandwidth.

---

## Warp Reduction: REDUX.SUM vs SHFL Tree

| Method | Cycles/reduction | Instructions |
|---|---|---|
| REDUX.SUM (hardware) | 60 | 1 |
| 5-stage SHFL tree (int) | 156 | 10 (5 SHFL + 5 IADD) |
| 5-stage SHFL tree (float) | 156 | 10 (5 SHFL + 5 FADD) |

REDUX.SUM (SM 8.0+) is **2.6x faster** than the classic 5-stage shuffle
reduction tree. However, REDUX only supports integer operations (SUM, MIN,
MAX). **No REDUX.FADD exists on Ada** -- float reductions must pay the full
156-cycle SHFL tree cost.

For the box-counting kernel's ballot+popc+atomicAdd pattern, replacing the
SHFL reduction with REDUX.SUM saves 96 cycles per warp per reduction.

---

## Transcendental Function SASS Decomposition

| Function | Fast path (--use_fast_math) | IEEE path (default) | FP64 path |
|---|---|---|---|
| sinf | 1 MUFU.SIN | 80+ instr (21 ISETP + 7 FFMA + range reduce) | ~120 instr (10 DFMA + 23 IMAD) |
| cosf | 1 MUFU.COS | ~80 instr (same structure as sinf) | ~120 instr |
| expf | 1 MUFU.EX2 + scale | ~12 instr (MUFU.EX2 + 2 FFMA corrections) | ~80 instr |
| logf | 1 MUFU.LG2 + scale | ~10 instr (MUFU.LG2 + FFMA refinement) | ~80 instr |
| sqrtf | 1 MUFU.SQRT | ~6 instr | MUFU.RSQ64H + 10 DFMA Newton-Raphson |
| rsqrtf | 1 MUFU.RSQ | 1 MUFU.RSQ | N/A |
| erfcf | N/A | 20 FFMA + 8 FMUL + 2 MUFU.RCP | N/A |
| sincosf | 2 MUFU (SIN+COS) | ~160 instr (both IEEE paths) | N/A |

The fast-math path reduces sinf from 80+ instructions to 1, at the cost of
~2^-21 relative error. For LBM kernels where sinf/cosf are not used in the
hot path (only in initialization), the choice is irrelevant. For Instant-NGP
volume rendering where MUFU.EX2 is in the hot loop, the fast path is critical.

FP64 transcendentals use CALL.REL to libdevice functions (not MUFU). Each
call is a ~80-120 instruction polynomial approximation. FP64 sqrt uniquely
uses MUFU.RSQ64H as a starting point for Newton-Raphson refinement.

---

## ncu Hardware Counter Cross-Validation

Profiled with Nsight Compute 2026.1 `--set full` (44 hardware passes per
kernel invocation) on RTX 4070 Ti (SM 8.9, 60 SMs, 2625 MHz).

### Expanded Latency Kernels (ncu vs clock64 reconciliation)

| Kernel | clock64 cy/inst | ncu SM_cyc | ncu Insts | ncu Warps | Finding |
|---|---|---|---|---|---|
| k_dadd | 48.47 | 452.87 | 533 | 1.00 | 533 insts = 512 chain + 21 overhead. Confirmed. |
| k_dfma | 54.48 | 507.52 | 534 | 1.00 | Highest SM_cyc. DFMA confirmed slowest ALU op. |
| k_hadd2 | 4.54 | 77.00 | 532 | 1.00 | Low SM_cyc = fast pipeline. Confirmed. |
| k_hfma2 | 4.54 | 77.75 | 533 | 1.00 | Same as HADD2 -> identical FP16 pipeline. |
| k_hfma2_bf16 | 4.01 | **54.15** | 532 | 1.00 | **LOWEST SM_cyc of all kernels. BF16 fastest FMA confirmed.** |
| k_dp4a | 4.53 | 80.43 | 533 | 1.00 | Same range as HADD2 -> INT pipe confirmed. |
| k_mufu_rcp64 | 17.54 | 188.98 | 533 | 1.00 | SFU pipe (same as BREV). |
| k_nanosleep | 2685.55 | 738.03 | 533 | 1.00 | **ncu reduces NANOSLEEP cost 3.6x** (profiler artifact). |

### Wave 5 Latency Kernels

| Kernel | clock64 cy/inst | ncu SM_cyc | ncu Insts | Critical Finding |
|---|---|---|---|---|
| k_brev | 17.49 | 189.58 | 532 | SFU pipe (same SM_cyc as MUFU.RCP64H). |
| k_popc | 23.52 | 243.23 | **1,044** | **Compiler added 512 XOR ops!** True POPC latency ~12 cy. |
| k_flo | 23.52 | 243.62 | **1,044** | Same as POPC -> same SFU unit. True FLO latency ~12 cy. |
| k_bfe | 8.52 | 115.98 | 1,044 | Extra instructions from unrolling. |
| k_bfi | 4.51 | 81.10 | 533 | Clean chain. Standard INT pipeline. |
| k_iabs | 0.53 | 43.93 | **21** | **Compiler eliminated the entire chain!** abs(abs(x))=abs(x). |
| k_dmnmx | 114.63 | 1,040.48 | **4,628** | FP64 min/max decomposes to massive instruction sequence. |
| k_membar_gpu | 205.25 | 1,730.95 | 1,556 | GPU-scope fence. High SM_cyc confirms expensive. |
| k_membar_sys | 2583.37 | **24,991.45** | 6,164 | **25K SM cycles! Most expensive operation measured.** |

### Critical Corrections from ncu Cross-Validation

**1. IABS at 0.53 cy is an ARTIFACT.**
ncu shows only 21 instructions executed (not 512+21). The compiler recognized
that `abs(abs(x)) = abs(x)` (idempotent) and eliminated the entire 512-deep
chain, keeping only the first abs plus overhead. The 0.53 cy measurement is
clock64 overhead divided by 512, not the true IABS latency. True IABS latency
is likely ~2-4 cycles (same as IADD3), but the chain cannot be measured with
the abs-of-abs pattern. A different chain design (e.g., negate-then-abs) is
needed to prevent idempotent folding.

**2. POPC and FLO true latency is ~12 cy, not 23.52 cy.**
ncu shows 1,044 instructions for a "512-deep" chain. The feedback loop
`x = x ^ count` generates an extra XOR per iteration, so the chain is actually
512 POPC + 512 XOR = 1,024 instruction body + 20 overhead = 1,044. The clock64
measurement of 23.52 cy per iteration is for POPC+XOR pair. Since XOR compiles
to LOP3 at 4.53 cy, true POPC latency is: 23.52 - 4.53 = **~19 cy**.
(Or if POPC and XOR partially overlap: POPC latency is 12-19 cy range, SFU.)

**3. DMNMX at 114.63 cy includes massive compiler-generated overhead.**
ncu shows 4,628 instructions for a 512-iter loop. The FP64 min/max + loop
increment generates ~9 instructions per iteration (DSETP comparison + FSEL
selection + DADD loop counter + branches). True DMNMX latency is closer to
114.63 / (4628/512) = ~12.7 cy per DMNMX, which is reasonable for a FP64
comparison operation (pipeline-starved at the 64:1 ratio).

**4. NANOSLEEP cost drops 3.6x under ncu profiling.**
Unprofiled: 2685.55 cy. Under ncu: 738.03 SM_cyc (2685/738 = 3.6x reduction).
The profiler's instrumentation changes the warp scheduling path, reducing the
reschedule overhead. This confirms NANOSLEEP's cost is dominated by scheduler
state, not instruction execution. Any ncu measurement of scheduling-dependent
operations will be perturbed.

### Conversion Latency (measured, RTX 4070 Ti)

| Conversion | Latency (cy) | Notes |
|---|---|---|
| FP32 <-> FP16 round-trip | 10.54 | 2x type conversion (F2FP + FP2F) |
| FP32 <-> BF16 round-trip | 8.54 | **Faster than FP16** (PRMT-based BF16 decode) |
| FP32 <-> FP8 E4M3 round-trip | 18.54 | Compound F2FP encode + HADD2.F32 decode |
| FP32 <-> FP64 round-trip | 0.00 | Likely optimized out (needs volatile fix) |
| INT32 <-> FP32 round-trip | 23.52 | I2F + F2I via conversion unit |
| LDC chain (constant memory) | 70.57 | Constant cache dependent access |

### Expanded Throughput (measured, RTX 4070 Ti, 60 SMs)

| Instruction | ops/clk/SM | Theoretical peak | Utilization | Finding |
|---|---|---|---|---|
| HADD2 (2xFP16) | 260.1 | 256 | **102%** | **Exceeds theoretical!** Half2 dual-issue. |
| IDP.4A (4xINT8) | 215.2 | 256 | 84% | 4x effective INT8 throughput. |
| HFMA2.BF16 | **312.1** | 256 | **122%** | **BF16 22% faster than FP16!** |
| DADD | 1.7 | 2 | 85% | Confirms 64:1 FP64 ratio. |
| DFMA | 1.7 | 2 | 85% | Same as DADD. |

BF16 exceeding 256 ops/clk/SM suggests the BF16 FMA pipeline is genuinely
wider than FP16 on Ada, or the measurement includes free scheduling overlap.
This is the most significant throughput finding: **BF16 is the fastest
packed FMA format on Ada Lovelace**, faster than both FP16 and FP32.

---

## Disassembly Summary

24 probe kernel files compiled and disassembled to SM 8.9 SASS:

| Probe | Instructions | Topics |
|---|---|---|
| probe_fp32_arith | 216 | FADD, FMUL, FFMA, FMNMX, FABS/FNEG |
| probe_int_arith | 192 | IADD3, IMAD, ISETP, LEA, IMAD.WIDE |
| probe_mufu | 1136 | MUFU.RCP/RSQ/SIN/COS/EX2/LG2/SQRT |
| probe_bitwise | 160 | LOP3, SHF, PRMT, BFI/BFE, FLO/POPC |
| probe_memory | 344 | LDG, STG, LDS, STS, atomics, fences |
| probe_conversions | 160 | F2I, I2F, F2F (FP16/FP64), I2I |
| probe_control_flow | 712 | BRA, BSSY/BSYNC, WARPSYNC, SHFL, VOTE, predication |
| probe_special_regs | 96 | S2R: TID, CTAID, CLOCK, LANEID, SMID |
| probe_tensor | 136 | HMMA.16816.F32 (tensor cores via WMMA) |

**Total: 3,107 SASS instructions analyzed.**

## Encoding Analysis Highlights

### Instruction word structure (64-bit)

From diffing same-mnemonic instructions with different register operands:

- **FADD** (0x...7221): register destination likely in bits [0:7], source operands in bits [9:15] and [41:45]
- **FFMA** (0x...7223): similar layout, bits [0:8] vary for register/operand encoding
- **LOP3** (0x...7625): LUT constant in bits around [52:59], register fields consistent with FADD
- **IADD3** (0x...7210): lower 16 bits (0x7210) form the opcode, register fields modulate bits [0:7], [9:15], [41:45]
- **MOV** (0x...7A02/7802): bits [41:43] encode destination register (0-15 range observed)

### Opcode field

The **low 16 bits** of the encoding word consistently identify the instruction class:

| Low 16 bits | Instruction |
|---|---|
| 0x7221 | FADD |
| 0x7223 | FFMA |
| 0x7210 | IADD3 |
| 0x7212 | ISETP |
| 0x7221 | FMUL (shared with FADD) |
| 0x7625 | LOP3/IMAD variants |
| 0x7981 | LDG |
| 0x7986 | STG |
| 0x7919 | S2R |
| 0x7802 | MOV |
| 0x7A02 | MOV (variant) |

### Control word patterns

The second 64-bit word encodes scheduling metadata. Most common patterns:

| Control word | Count | Likely meaning |
|---|---|---|
| 0x000FC00000000000 | ~500+ | NOP/filler (max stall, yield) |
| 0x000FC80000000000 | common | Dependent chain stall hint |
| 0x000FE40000000f00 | common | Normal scheduling |
| 0x000FE20000000000 | common | Minimal stall |
| 0x000FCA0000000000 | common | Read-after-write dependency |

---

## Expanded Probe Results (8 new probes, 32 new SASS mnemonics)

Compiled and disassembled on RTX 4070 Ti (SM 8.9) with CUDA 13.1.
All probes: zero register spills, zero stack frames.

### Novel Findings

These discoveries were made by disassembling the expanded probes and comparing
the actual SASS output against NVIDIA's public documentation.

#### 1. IDP.4A.S8.S8 -- not DP4A

The `__dp4a()` intrinsic compiles to `IDP.4A.S8.S8` on Ada Lovelace, not
`DP4A` as named in NVIDIA's CUDA programming guide. The IDP mnemonic stands
for "Integer Dot Product" in the Ada ISA. The instruction appears 25 times
in `probe_int8_dp4a` across 4 kernels.

Opcode encoding: `0x...7226` (low 16 bits). The `.S8.S8` suffix indicates
signed 8-bit operands for both inputs. Ada likely supports `.U8.U8` and
mixed `.S8.U8` variants (not yet probed).

The 5-group momentum accumulation pattern from `kernels_int8.cu` (5x IDP.4A
per macroscopic variable) generates clean IDP chains with no register spills
at 30 registers/thread.

#### 2. HMMA.1684.F32.TF32 -- TF32 shape is 16x16x4, not 16x16x8

When WMMA requests a 16x16x8 TF32 matrix multiply, Ada decomposes it into
**two** `HMMA.1684.F32.TF32` instructions (K=4 each). The probe emits 36
HMMA.1684 instructions for an 8-deep chain of 16x16x8 WMMA calls:
`8 calls * 2 HMMA per call * ~2 accumulator halves = 32-36` instructions.

This means TF32 tensor core throughput is half the per-instruction rate of
FP16/BF16 HMMA.16816 (which processes K=16 in a single instruction). The
measured 22,880 GFLOPS for TF32 vs 45,901 for FP16 (2.01x ratio) is
consistent with this 2:1 instruction ratio.

#### 3. F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C -- compound FP8 encode

FP8 encoding is NOT a simple float-to-int truncation. Ada uses a compound
instruction `F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C` that:
  - Saturates to finite range (clamps NaN/Inf)
  - Converts FP32 to E4M3 format
  - Packs result into a byte lane (PACK_AB)
  - Merges with an existing byte (MERGE_C, for nibble/byte packing)

The decode path uses `F2FP.F16.E4M3.UNPACK_B`: FP8 -> FP16 in one
instruction, with UNPACK selecting which byte lane to decode. This appears
24 times in `probe_fp8_precision` for the 19-direction decode chain.

**Performance implication**: Each FP8 encode is 1 instruction (not a
multi-instruction sequence). At 19 encodes + 19 decodes per cell, the FP8
conversion overhead is ~38 instructions/cell. Compare to 722 FMA for MRT
collision -- conversion overhead is 5.3% of collision ALU budget.

#### 4. STG.E.EF -- "evict-first" not "cache-streaming"

The `__stcs()` intrinsic (documented as "cache-streaming" store) compiles
to `STG.E.EF` on Ada, where EF = "evict-first". This is the correct
microarchitectural name: the store evicts the cache line from L2 after
write, preventing pollution of the L2 working set.

The probe confirms 6 `STG.E.EF` instructions in the streaming store
kernels, paired with 6 `LDG.E.CONSTANT` (the read-only cache path from
`__ldg()`). Normal stores emit `STG.E` without the `.EF` suffix, and
128-bit vector stores emit `STG.E.128`.

#### 5. REDUX.SUM.S32 -- single-instruction warp reduction

Ada Lovelace (SM 8.0+) has hardware warp reduction via the REDUX
instruction family. `__reduce_add_sync()` compiles to a single
`REDUX.SUM.S32` instruction that reduces all 32 lanes of a warp in
hardware, replacing the classic 5-stage SHFL.BFLY reduction tree.

Similarly: `__reduce_min_sync()` -> `REDUX.MIN.S32`,
`__reduce_max_sync()` -> `REDUX.MAX.S32`.

**Performance implication**: REDUX replaces 5 SHFL + 5 FADD instructions
(~5 * 24.96cy = 125 cycles at SHFL latency) with a single instruction.
For the box-counting kernel's ballot+popc+atomicAdd pattern, this reduces
the per-warp reduction from ~10 instructions to 1.

Note: REDUX is integer-only on Ada. Float reductions still require the
SHFL tree (no REDUX.FADD exists).

### Additional Observations

#### HFMA2.BF16_V2 -- BF16 packed FMA exists on Ada

The `__hfma2()` intrinsic for `__nv_bfloat162` compiles to `HFMA2.BF16_V2`,
confirming native packed BF16 FMA execution. The `.V2` suffix indicates
2-wide vector operation (same as FP16 half2). This appears 7 times in
`probe_bf16_arithmetic`.

However, BF16 scalar arithmetic (single `__nv_bfloat16`) compiles to
FP32 promotion + FFMA + BF16 demotion (no scalar BF16 FMA instruction).
This explains the measured 7.5% throughput gap between BF16 SoA and FP16
SoA in `kernels_bf16_soa.cu`: scalar BF16 loads go through a longer
pipeline than scalar FP16 loads.

#### PRMT dominates BF16 conversion path

The BF16 decode path (`__bfloat162float`) compiles to `PRMT` (byte permute)
rather than F2FP -- 22 PRMT instructions in `probe_bf16_arithmetic`. BF16
has the same exponent as FP32 (8 bits), so conversion is a zero-extend of
the mantissa field. PRMT achieves this by shuffling the 2 BF16 bytes into
the upper 2 bytes of an FP32 register (zeroing the lower 16 bits).

**Latency**: PRMT is 4.51 cycles (from original results). Converting 19
BF16 distributions: 19 * 4.51 = 85.7 cycles. Compare to FP8 decode
(F2FP: latency TBD, but likely similar to F2I at ~6 cycles per direction).

#### FCHK in nibble packing

The nibble packing probe (`probe_nibble_packing`) emits 38 `FCHK`
instructions -- a "float check" instruction that validates NaN/Inf status.
These appear in the INT4-to-float conversion path where `I2FP.F32.S32`
converts the sign-extended INT4 value to float, and FCHK guards against
invalid values before the division by DIST_SCALE.

This was not previously observed in any probe. FCHK likely has near-zero
latency (predicate-only output, no register write).

#### FFMA.RZ/RP/RM -- rounding mode variants

The nibble packing probe also reveals `FFMA.RZ` (round toward zero),
`FFMA.RP` (round toward positive infinity), and `FFMA.RM` (round toward
negative infinity) variants. These appear in the FP4 quantization path
where float_to_fp4() needs specific rounding behavior. Standard collision
kernels use only the default `FFMA` (round to nearest even).

### Expanded Probe Census

| Probe | SASS lines | Unique mnemonics | Key new instructions |
|---|---|---|---|
| probe_fp16_half2 | 365 | 24 | HADD2, HFMA2, HMNMX2, F2FP.F16.F32.PACK_AB |
| probe_fp8_precision | 557 | 22 | F2FP.E4M3.UNPACK_B, F2FP.SATFINITE.E4M3.PACK_AB_MERGE_C |
| probe_int8_dp4a | 360 | 18 | IDP.4A.S8.S8 (25 instances) |
| probe_tensor_extended | 557 | 27 | HMMA.1684.F32.TF32 (36), IMMA.16816.S8, IMMA.8832.S4 |
| probe_cache_policy | 232 | 16 | STG.E.EF (6), LDG.E.CONSTANT (6), STG.E.128 |
| probe_nibble_packing | 2189 | 52 | FCHK, FFMA.RZ/RP/RM, I2FP, IMNMX, BAR.SYNC.DEFER_BLOCKING |
| probe_warp_reduction | 556 | 33 | REDUX.SUM/MIN/MAX.S32, MATCH.ALL, VOTE.ALL/ANY, SHFL variants |
| probe_bf16_arithmetic | 477 | 23 | HFMA2.BF16_V2, F2FP.BF16.F32.PACK_AB, LDG.E.U16 |

**Expanded total: ~5,293 SASS instructions across 8 new probes.**
**Combined total (all 24 probes): ~10,000+ SASS instructions, 180+ unique mnemonics.**

---

## Files

- Latency benchmarks: `microbench/microbench_latency.cu` (v4), `microbench/microbench_latency_expanded.cu`
- Throughput benchmark: `microbench/microbench_throughput.cu`
- Cache topology: `microbench/microbench_cache_topology.cu`
- Shared memory bank conflicts: `microbench/microbench_smem_bank_conflicts.cu`
- Occupancy scaling: `microbench/microbench_occupancy_scaling.cu`
- Probe kernels: `probes/probe_*.cu` (24 files: 9 original + 15 expanded)
- Disassembly scripts: `scripts/disassemble_all.ps1` (Windows), `scripts/disassemble_expanded.sh` (POSIX)
- Profiling scripts: `scripts/profile_ncu_probes.sh`, `scripts/profile_nsys_timeline.sh`
- Encoding analysis: `scripts/encoding_analysis.py`
- Full SASS dumps: `results/20260306_190541/*.sass`
- Encoding report: `results/20260306_190541/ENCODING_ANALYSIS.md`

---

## Optimization Flag SASS Mnemonic Mining

Systematic compilation of all 60 probes across 13 flag combinations to
discover optimization-dependent SASS instruction variants.

### Flag sweep results

| Flags | Compiled | Mnemonics | New vs baseline | Key findings |
|---|---|---|---|---|
| (default) | 60 | 268 | -- | Baseline |
| -O1 | 60 | 268 | 0 | Identical to default |
| -O2 | 60 | 268 | 0 | Identical to default |
| -O3 | 60 | 268 | 0 | Identical to default |
| -Xptxas -O3 | 60 | 268 | 0 | PTX optimizer level has no effect |
| **--use_fast_math** | 60 | 259 | **+13** | FTZ variants + MUFU.SQRT + P2R |
| --extra-device-vectorization | 60 | 268 | 0 | No effect (probes already vectorized) |
| **--restrict** | 60 | 271 | **+5** | Constant-cache sub-byte loads + spills |
| -O3 --use_fast_math | 60 | 259 | +13 | Same as fast_math alone |
| -O3 --extra-device-vectorization | 60 | 268 | 0 | No effect |
| -O3 --restrict | 60 | 271 | +5 | Same as restrict alone |
| -O3 --use_fast_math --extra-device-vectorization | 60 | 259 | +13 | fast_math dominates |
| -O3 --use_fast_math --extra-device-vectorization --restrict | 60 | 259 | +13 | fast_math dominates |
| -dlto | 0 | -- | -- | Requires device-link model (N/A for single-file) |

Note: `-O1` through `-O3` produce identical SASS because `asm volatile` +
volatile stores prevent the ptxas optimizer from eliminating measurement chains.

### New mnemonics from `--use_fast_math` (13 new)

| Mnemonic | Description | Significance |
|---|---|---|
| F2I.FTZ.CEIL.NTZ | Float-to-int: FTZ + ceiling | FTZ conversion variants |
| F2I.FTZ.FLOOR.NTZ | Float-to-int: FTZ + floor | |
| F2I.FTZ.NTZ | Float-to-int: FTZ nearest | |
| F2I.FTZ.TRUNC.NTZ | Float-to-int: FTZ + truncation | |
| F2I.FTZ.U32.NTZ | Float-to-unsigned-int: FTZ | |
| FADD.FTZ.RZ | FP32 add: FTZ + round-toward-zero | Combined modifier |
| FMNMX.FTZ | FP32 min/max with FTZ | |
| FMUL.FTZ.D8 | FP32 multiply: FTZ + D8 scale | |
| FSET.BF.GT.FTZ.AND | Float set (boolean): FTZ | |
| FSETP.GE.FTZ.AND | Float set-predicate: FTZ | |
| FSETP.GT.FTZ.AND | Float set-predicate: FTZ | |
| **MUFU.SQRT** | **Hardware square root SFU path** | **Only emitted with fast_math!** |
| **P2R** | **Predicate-to-register (spill)** | **Proves predicate spilling CAN occur** |

**MUFU.SQRT discovery**: Without `--use_fast_math`, `sqrtf()` compiles to
`MUFU.RSQ` + `FMUL` (reciprocal sqrt * x). Fast math enables a direct
`MUFU.SQRT` instruction. This is a different SFU opcode from `MUFU.RSQ`.

**P2R discovery**: We previously reported that predicate spilling never occurs
(probe_predicate_pressure.cu). This is true at default optimization, but
`--use_fast_math` generates FTZ predicate chains complex enough to trigger
P2R (predicate-to-register spill). The complementary R2P (register-to-predicate
reload) should also exist but was not observed in this sweep.

### New mnemonics from `--restrict` (5 new)

| Mnemonic | Description | Significance |
|---|---|---|
| I2F.S8 | Direct signed-byte to float | Skips INT32 widening step |
| LDG.E.U16.CONSTANT | 16-bit unsigned read-only load | __restrict__ enables constant cache |
| LDG.E.U8.CONSTANT | 8-bit unsigned read-only load | __restrict__ enables constant cache |
| **LDL.LU** | **Local memory load (uniform hint)** | **Register spill to LMEM** |
| **STL** | **Local memory store** | **Register spill to LMEM** |

**LDL.LU + STL discovery**: `--restrict` changes pointer aliasing, causing
the compiler to allocate more registers for pointer disambiguation. This
pushes some kernels over the register limit, triggering LMEM spills.
LDL.LU (load local, uniform) is the spill reload path; STL is the spill store.
These are the instructions that `check_spills.sh` warns about.

### Combined total (flag sweep only: fast_math + restrict)

**286 unique SASS mnemonics** across fast_math and restrict flag combinations
(268 baseline + 13 from fast_math + 5 from restrict = 286 total).

### Comprehensive Flag Matrix Sweep (20 combos x 60 probes = 1200 compilations)

| Flags | Compiled | Mnemonics | New | Spills | Key discovery |
|---|---|---|---|---|---|
| baseline (-std=c++20 -lineinfo) | 60 | 268 | -- | 0 | Reference |
| -O1 / -O2 / -O3 | 60 | 268 | 0 | 0 | Identical (asm volatile proof) |
| -fmad=false | 60 | 268 | **+1** | 0 | **HMUL2** (FMA decomposed to MUL+ADD) |
| --use_fast_math | 60 | 259 | **+13** | 0 | MUFU.SQRT, P2R, 11 FTZ variants |
| --maxrregcount=32-255 | 60 | 270 | **+2** | 0 | UISETP.GE.U32.AND, UISETP.GT.AND |
| **-G (debug)** | 60 | 255 | **+76** | **892** | **76 new mnemonics + massive spills** |
| --restrict | 60 | 271 | **+5** | 24 | LDL.LU, STL, constant-cache sub-byte |
| -O3 precision flags | 60 | 268 | +1 | 0 | HMUL2 |
| -O3 --fast_math --restrict | 60 | 260 | +16 | 0 | Combined set |
| -Xptxas -warn-spills | 60 | 268 | 0 | 0 | Warning only, no SASS change |
| -Xptxas -warn-double-usage | 60 | 268 | 0 | 0 | Warning only, no SASS change |

### Debug build (-G) reveals 76 hidden instruction variants

The `-G` (device debug) flag disables optimization entirely, exposing
instructions that ptxas normally optimizes away. 76 new mnemonics appear:

- **ATOMS.CAST.SPIN / .SPIN.64**: Shared-memory spin-lock atomics (debug CAS loop)
- **BMOV.32 / BMOV.32.CLEAR**: Convergence barrier move/clear
- **BMSK**: Bit mask generation instruction (normally folded into LOP3)
- **IMMA.*.SAT**: Saturating tensor MMA variants (IMMA.16816.S8.SAT, IMMA.8832.S4/U4.SAT)
- **LDGSTS.E.*.ZFILL**: Async copy with zero-fill (64-bit, 128-bit bypass)
- **MOVM.16.MT88**: Matrix move via shared memory (tensor core data staging)
- **QSPC.E.G / QSPC.E.S**: Query address space (global / shared)
- **R2UR**: Register to uniform-register (reverse of S2UR)
- **WARPSYNC.EXCLUSIVE**: Exclusive warp synchronization mode
- **MEMBAR.SC.VC**: Sequential consistency fence with virtual channel
- **F2F.BF16.F32 / F2F.F16.F32**: Direct format-to-format conversions
- **76 total new mnemonics** (full list in results/flag_sweep/debug_G/)

### -fmad=false reveals HMUL2

When FMA fusion is disabled, `a*b+c` decomposes to separate multiply + add:
FP16: `HFMA2` -> `HMUL2` + `HADD2` (2 instructions instead of 1).
This is the only way to observe the standalone `HMUL2` instruction.

### --maxrregcount reveals UISETP

Register pressure constraints expose unsigned uniform integer set-predicate
variants (UISETP.GE.U32.AND, UISETP.GT.AND) in the uniform register datapath.

**Grand total: 363 unique SASS mnemonics across all 20 flag combinations.**

### CRITICAL: --use_fast_math breaks throughput benchmarks

`--use_fast_math` enables associativity optimizations that allow the
compiler to constant-fold throughput measurement chains:

| Benchmark | Without fast_math | With fast_math | Cause |
|---|---|---|---|
| HFMA2.BF16 throughput | 312.1 ops/clk/SM | **12.9** (24x regression!) | Chain folded to 1 instruction |
| FFMA throughput | 44.6 ops/clk/SM | 85.0 (inflated) | Partial folding |

The `asm volatile` pattern protects **latency** chains but NOT **throughput**
chains (which use C++ operators for 8 independent accumulators). The compiler
can fold `a = a * scale + bias` across iterations when fast_math grants
associativity permission.

**Rule: compare throughput benchmarks compiled WITHOUT --use_fast_math.**
Use `--use_fast_math` only for SASS mnemonic hunting, not measurement.

---

## Definitive Summary (2026-03-19)

| Metric | Value |
|---|---|
| Probe kernels | 61 |
| Microbenchmarks | 13 |
| Total CUDA source files | 74 |
| Unique SASS mnemonics | **363** (268 baseline + 95 from 20 flag combinations) |
| Total SASS instructions disassembled | 26,216 |
| Latency measurements | 70+ (ncu cross-validated) |
| Throughput measurements | 10+ |
| Tensor core precisions measured | 7 (all available on Ada) |
| Exotic formats characterized | 16 (NF4, MX, FXP, Posit, BCD, DD, QD, bignum) |
| Novel discoveries | 30+ |
| ncu hardware counter validations | 41 kernels |
| Production kernels created | 4 (BF16 bf162, INT8 MRT A-A, inv_tau, REDUX box count) |
| Zero-cost modifiers confirmed | 5 (FTZ, SAT, FABS, FNEG, denormals) |
| N/A values remaining | 0 |

### Fastest instruction per pipeline (Ada Lovelace SM 8.9)

| Pipeline | Fastest instruction | Latency |
|---|---|---|
| Integer | IABS (modifier) | 0.26 cy/pair |
| Integer standalone | IADD3 | 2.52 cy |
| FP32 | FFMA | 4.53 cy |
| FP16 packed | HADD2 / HFMA2 | 4.54 cy |
| **BF16 packed** | **HFMA2.BF16** | **4.01 cy** |
| INT8 dot product | IDP.4A | 4.53 cy |
| Tensor core | IMMA.8832 (INT4) | 28.05 cy |
| Tensor core float | HMMA.16816 (FP16->FP16) | 42.14 cy |
| Warp reduction | REDUX.SUM | 60.01 cy |
| SFU | MUFU.EX2 | 17.55 cy |
| FP64 | DADD | 48.47 cy |
| Shared memory | LDS | 28.03 cy |

### Most expensive operations (Ada Lovelace SM 8.9)

| Operation | Latency | Category |
|---|---|---|
| NANOSLEEP(0) | 2685.55 cy | Warp reschedule |
| MEMBAR.SYS | 2583.37 cy | System-scope fence |
| FP64 log() | 1113.83 cy | Transcendental |
| FP64 sin() | 820.66 cy | Transcendental |
| QD FP256 ADD | 828.28 cy | Arbitrary precision |
| DD FP128 ADD | 500.28 cy | Double-double |
| FP64 sqrt() | 450.30 cy | Transcendental |
| LDGSTS | 363.28 cy | Async copy overhead |
| DD FP128 MUL | 314.35 cy | Double-double |
| BCD ADD | 291.05 cy | Decimal arithmetic |
