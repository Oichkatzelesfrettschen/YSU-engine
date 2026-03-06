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

## Files

- Latency benchmark: `microbench/microbench_latency.cu` (v4, ptxas-proof)
- Throughput benchmark: `microbench/microbench_throughput.cu`
- Probe kernels: `probes/probe_*.cu` (9 files)
- Disassembly scripts: `scripts/disassemble_all.ps1`
- Encoding analysis: `scripts/encoding_analysis.py`
- Full SASS dumps: `results/20260306_190541/*.sass`
- Encoding report: `results/20260306_190541/ENCODING_ANALYSIS.md`
