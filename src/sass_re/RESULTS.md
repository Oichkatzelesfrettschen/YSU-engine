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

## Disassembly Summary

9 probe kernel files compiled and disassembled to SM 8.9 SASS:

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
**Combined total (original + expanded): ~8,400 SASS instructions, 17 probes.**

---

## Files

- Latency benchmark: `microbench/microbench_latency.cu` (v4, ptxas-proof)
- Throughput benchmark: `microbench/microbench_throughput.cu`
- Probe kernels: `probes/probe_*.cu` (17 files: 9 original + 8 expanded)
- Disassembly scripts: `scripts/disassemble_all.ps1` (Windows), `scripts/disassemble_expanded.sh` (POSIX)
- Profiling scripts: `scripts/profile_ncu_probes.sh`, `scripts/profile_nsys_timeline.sh`
- Encoding analysis: `scripts/encoding_analysis.py`
- Full SASS dumps: `results/20260306_190541/*.sass`
- Encoding report: `results/20260306_190541/ENCODING_ANALYSIS.md`
