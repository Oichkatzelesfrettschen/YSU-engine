# Ada Lovelace SM 8.9 SASS Instruction Reference

Definitive inventory of all 370 SASS mnemonics observed on NVIDIA Ada Lovelace
SM 8.9 (RTX 4070 Ti) with measured latencies and compilation flag requirements.

- Generated: 2026-03-19
- Hardware: NVIDIA GeForce RTX 4070 Ti (AD104, SM 8.9, 60 SMs, 2625 MHz)
- Compiler: CUDA 13.1 (nvcc V13.1.115)
- Probes: 61 files in `src/sass_re/probes/`
- Microbenchmarks: 13 files in `src/sass_re/microbench/`
- Compilations: 1200 (60 probes x 20 flag combinations)
- Latencies: measured via 512-deep dependent chains, ncu cross-validated

Latency notation:
- Exact values (e.g., "4.53 cy") are from direct measurement
- Approximate values (e.g., "~4.53 cy") are inferred from same-pipeline instructions
- Empty latency = not directly measured (SASS-only probe, no timing chain)

---


### Atomic Global + Reduction (24 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `ATOM.E.ADD.64.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.ADD.STRONG.GPU` | ~100-200 cy | barrier probes (-O3 --restrict) | Global atomic add with strong ordering (G = global scope) |
| `ATOM.E.ADD.F32.FTZ.RN.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.ADD.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.AND.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.CAS.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.EXCH.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.MAX.S32.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.MIN.S32.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.OR.STRONG.GPU` | ~100-200 cy | default | |
| `ATOM.E.XOR.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.AND.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.CAS.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.EXCH.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.MAX.S32.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.MIN.S32.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.OR.STRONG.GPU` | ~100-200 cy | default | |
| `ATOMG.E.XOR.STRONG.GPU` | ~100-200 cy | default | |
| `RED.E.ADD.F32.FTZ.RN.STRONG.GPU` | ~100-200 cy | default | |
| `RED.E.ADD.STRONG.GPU` | ~100-200 cy | default | |
| `REDUX.MAX.S32` | ~60 cy | default | |
| `REDUX.MIN.S32` | ~60 cy | default | |
| `REDUX.OR` | ~60 cy | default | |
| `REDUX.SUM` | 60.01 cy (2.6x faster than SHFL tree) | default | |
| `REDUX.SUM.S32` | 60.01 cy | default | |

### Atomic Shared (3 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `ATOMS.CAST.SPIN` | ~20 cy (smem) | -G | |
| `ATOMS.CAST.SPIN.64` | ~20 cy (smem) | -G | |
| `ATOMS.POPC.INC.32` | ~20 cy (smem) | default | |

### Barrier/Sync (3 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BAR.ARV` | ~20-50 cy | barrier probes (-O3 --restrict) | **Split-phase arrive-without-wait.** Thread signals arrival but continues executing. Paired with BAR.SYNC for deferred wait. |
| `BAR.SYNC` | ~20-50 cy | default | |
| `BAR.SYNC.DEFER_BLOCKING` | ~20-50 cy | default | |
| `DEPBAR.LE` | ~0 cy (token) | default | |

### Bit Manipulation (25 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BMSK` | ~4 cy | -G | |
| `BREV` | 17.51 cy (SFU) | default | |
| `FLO.U32` | ~7-8 cy | default | |
| `FLO.U32.SH` | ~7-8 cy | default | |
| `LOP3.LUT` | 4.53 cy | default | |
| `PLOP3.LUT` | ~4 cy | default | |
| `POPC` | ~7-8 cy (multi-cycle INT, corrected from 23.52) | default | |
| `PRMT` | 4.52 cy | default | |
| `SGXT` | ~4 cy | default | |
| `SGXT.U32` | ~4 cy | default | |
| `SHF.L.U32` | 4.52 cy | default | |
| `SHF.L.U32.HI` | ~4.52 (similar) | default | |
| `SHF.L.U64.HI` | ~4.52 cy | default | |
| `SHF.L.W.U32` | ~4.52 cy | default | |
| `SHF.L.W.U32.HI` | ~~4.52 (similar) | default | |
| `SHF.R.S32.HI` | 4.52 cy | default | |
| `SHF.R.S64` | ~4.52 cy | default | |
| `SHF.R.U32` | ~4.52 (similar) | default | |
| `SHF.R.U32.HI` | 4.52 cy | default | |
| `SHF.R.U64` | ~4.52 cy | default | |
| `SHF.R.W.U32` | ~4.52 cy | default | |
| `SHFL.BFLY` | 24.96 cy | default | |
| `SHFL.DOWN` | ~24.96 cy | default | |
| `SHFL.IDX` | ~24.96 cy | default | |
| `SHFL.UP` | ~24.96 cy | default | |

### Cache Control (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `CCTL.E.PF1` | ~4 cy | default | |
| `CCTL.E.PF2` | ~4 cy | default | |
| `CCTL.IVALL` | ~4 cy | default | |
| `QSPC.E.G` | ~4 cy | -G | |
| `QSPC.E.S` | ~4 cy | -G | |

### Control Flow (14 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BMOV.32` | ~4 cy | -G | |
| `BMOV.32.CLEAR` | ~4 cy | -G | |
| `BRA` | ~0 cy (branch) | default | |
| `BRA.CONV` | ~0 cy (branch) | barrier probes | **Convergent branch** (compiler marks branches where all threads take same path) |
| `BRA.DIV` | ~0 cy (branch) | barrier probes | **Divergent branch** (compiler marks branches where threads may diverge) |
| `BRA.CONV` | ~0 cy (branch) | default | |
| `BRX` | ~4 cy | default | |
| `BSSY` | ~4 cy | default | |
| `BSYNC` | ~4 cy | default | |
| `CALL.ABS.NOINC` | ~4 cy | -G | |
| `CALL.REL.NOINC` | ~4 cy | default | |
| `EXIT` | ~0 cy (thread termination) | default | |
| `NOP` | 0 cy (pipeline filler) | default | |
| `RET.ABS.NODEC` | ~4 cy | -G | |
| `RET.REL.NODEC` | ~4 cy | default | |
| `YIELD` | 2676.61 cy (=NANOSLEEP) | default | |

### Conversion (38 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `F2F.BF16.F32` | ~6-10 cy | default | |
| `F2F.F16.F32` | ~6-10 cy | default | |
| `F2F.F16.F32.RM` | ~6-10 cy | default | |
| `F2F.F16.F32.RP` | ~6-10 cy | default | |
| `F2F.F16.F32.RZ` | ~6-10 cy | default | |
| `F2F.F32.F64` | ~6-10 cy | default | |
| `F2F.F64.F32` | ~6-10 cy | default | |
| `F2FP.BF16.F32.PACK_AB` | ~8.54 cy (BF16 round-trip) | default | |
| `F2FP.F16.E4M3.UNPACK_B` | ~6 cy (FP8 decode) | default | |
| `F2FP.F16.E5M2.UNPACK_B` | ~6 cy (FP8 E5M2 decode) | default | |
| `F2FP.F16.F32.PACK_AB` | ~10.54 cy (FP16 round-trip) | default | |
| `F2FP.F16.F32.PACK_AB.RZ` | ~~10.54 (similar) | default | |
| `F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C` | ~18.54 cy (FP8 round-trip) | default | |
| `F2FP.SATFINITE.E5M2.F32.PACK_AB_MERGE_C` | ~18.53 cy (FP8 E5M2 round-trip) | default | |
| `F2I.CEIL.NTZ` | ~6-12 cy | default | |
| `F2I.F64` | ~6-12 cy | default | |
| `F2I.FLOOR.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.CEIL.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.FLOOR.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.TRUNC.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.U32.NTZ` | ~6-12 cy | default | |
| `F2I.FTZ.U32.TRUNC.NTZ` | ~6-12 cy | default | |
| `F2I.NTZ` | ~6-12 cy | default | |
| `F2I.TRUNC.NTZ` | ~12.03 cy (F2I+I2F round-trip) | default | |
| `F2I.U32.NTZ` | ~6-12 cy | default | |
| `F2I.U32.TRUNC.NTZ` | ~6-12 cy | default | |
| `I2F.F64` | ~6 cy | default | |
| `I2F.F64.S64` | ~6 cy | default | |
| `I2F.RM` | ~6 cy | default | |
| `I2F.RP` | ~6 cy | default | |
| `I2F.S16` | ~44.51 cy (INT16 I2F+F2I chain) | default | |
| `I2F.S8` | ~6 cy (direct byte-to-float) | --restrict | |
| `I2F.U16` | ~6 cy | default | |
| `I2F.U32.RP` | ~6 cy | default | |
| `I2FP.F32.S32` | ~6 cy | default | |
| `I2FP.F32.S32.RZ` | ~~6 (similar) | default | |
| `I2FP.F32.U32` | ~6 cy | default | |

### Data Movement (2 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MOV` | ~2 cy (register move) | default | |
| `SEL` | ~4.53 cy | default | |

### FP16/BF16 Packed + Tensor Core Float (10 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `HADD2` | 4.54 cy | default | |
| `HADD2.F32` | ~4.54 cy | default | |
| `HFMA2` | 4.54 cy | default | |
| `HFMA2.BF16_V2` | 4.01 cy (FASTEST FMA on Ada) | default | |
| `HMMA.16816.F16` | 42.14 cy/WMMA (fastest float TC) | default | |
| `HMMA.16816.F32` | 66.28 cy/WMMA (256 FMA) | default | |
| `HMMA.16816.F32.BF16` | 66.33 cy/WMMA (=FP16->FP32) | default | |
| `HMMA.1684.F32.TF32` | 66.66 cy/2xHMMA (TF32 via 2 instructions) | default | |
| `HMNMX2` | ~4.54 cy | default | |
| `HMUL2` | ~4.54 cy (only with -fmad=false) | -fmad=false | |

### FP32 Arithmetic (42 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `FADD` | 4.52 cy | default | |
| `FADD.FTZ` | ~4.52 cy | default | |
| `FADD.FTZ.RZ` | ~4.52 cy | default | |
| `FADD.RZ` | ~4.52 cy | default | |
| `FADD.SAT` | 4.52 cy (SAT=FREE) | default | |
| `FCHK` | ~0 cy (pred only) | default | |
| `FFMA` | 4.53 cy | default | |
| `FFMA.FTZ` | 4.51 cy (FTZ=FREE) | default | |
| `FFMA.RM` | ~4.53 cy | default | |
| `FFMA.RP` | ~4.53 cy | default | |
| `FFMA.RZ` | ~4.53 cy | default | |
| `FFMA.SAT` | ~4.53 (similar) | default | |
| `FMNMX` | ~4.53 cy | default | |
| `FMNMX.FTZ` | ~4.53 cy | default | |
| `FMUL` | 4.52 cy | default | |
| `FMUL.D8` | ~4.52 (similar) | default | |
| `FMUL.FTZ` | ~4.52 (similar) | default | |
| `FMUL.FTZ.D8` | ~4.52 cy | default | |
| `FMUL.RZ` | ~4.52 (similar) | default | |
| `FMUL.SAT` | ~4.52 (similar) | default | |
| `FSEL` | 8.52 cy | default | |
| `FSET.BF.GT.AND` | ~4.53 cy | default | |
| `FSET.BF.GT.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.EQ.AND` | ~4.53 cy | default | |
| `FSETP.EQ.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.EQ.OR` | ~4.53 cy | default | |
| `FSETP.GE.AND` | ~8.52 cy | default | |
| `FSETP.GE.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.GEU.AND` | ~4.53 cy | default | |
| `FSETP.GEU.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.GEU.OR` | ~4.53 cy | default | |
| `FSETP.GT.AND` | ~8.52 cy | default | |
| `FSETP.GT.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.GTU.AND` | ~4.53 cy | default | |
| `FSETP.GTU.FTZ.AND` | ~8.52 cy | default | |
| `FSETP.GTU.OR` | ~4.53 cy | default | |
| `FSETP.LE.AND` | ~4.53 cy | default | |
| `FSETP.LE.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.LT.AND` | ~4.53 cy | default | |
| `FSETP.LT.FTZ.AND` | ~4.53 cy | default | |
| `FSETP.NEU.AND` | ~8.52 cy | default | |
| `FSETP.NEU.FTZ.AND` | ~4.53 cy | default | |

### FP64 Arithmetic (19 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `DADD` | 48.47 cy | default | |
| `DFMA` | 54.48 cy | default | |
| `DFMA.RM` | ~54.48 (similar) | default | |
| `DFMA.RP` | ~54.48 (similar) | default | |
| `DMUL` | 48.47 cy | default | |
| `DMUL.RP` | ~48.47 (similar) | default | |
| `DSETP.EQ.AND` | ~38 cy | default | |
| `DSETP.EQU.AND` | ~38 cy | default | |
| `DSETP.GE.AND` | ~38 cy | default | |
| `DSETP.GEU.AND` | ~38 cy | default | |
| `DSETP.GT.AND` | ~38 cy | default | |
| `DSETP.GTU.AND` | ~38 cy | default | |
| `DSETP.LE.AND` | ~38 cy | default | |
| `DSETP.LT.AND` | ~38 cy | default | |
| `DSETP.MAX.AND` | ~38 cy | default | |
| `DSETP.MIN.AND` | ~38 cy | default | |
| `DSETP.NAN.AND` | ~38 cy | default | |
| `DSETP.NE.AND` | ~38 cy | default | |
| `DSETP.NEU.AND` | ~38 cy | default | |

### Fence (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MEMBAR.ALL.GPU` | 205.25 cy (__threadfence) | default | |
| `MEMBAR.SC.CTA` | ~28-2583 cy | default | |
| `MEMBAR.SC.GPU` | ~28-2583 cy | default | |
| `MEMBAR.SC.SYS` | 2583.37 cy (system-scope) | default | |
| `MEMBAR.SC.VC` | ~28-2583 cy | -G | |

### Integer Arithmetic (24 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `IABS` | 0.26 cy/pair (sub-cycle modifier) | default | |
| `IADD3` | 2.52 cy | default | |
| `IADD3.X` | ~2.59 cy (carry propagation) | default | |
| `IDP.4A.S8.S8` | 4.53 cy (4x effective INT8) | default | |
| `IMAD` | 4.53 cy | default | |
| `IMAD.HI` | ~4.53 cy | default | |
| `IMAD.HI.U32` | ~4.53 cy | default | |
| `IMAD.IADD` | ~4.53 cy | default | |
| `IMAD.MOV` | ~4.53 (similar) | default | |
| `IMAD.MOV.U32` | ~4.53 cy | default | |
| `IMAD.SHL` | ~4.53 (similar) | default | |
| `IMAD.SHL.U32` | ~4.53 cy | default | |
| `IMAD.U32` | ~4.53 (similar) | default | |
| `IMAD.WIDE` | 2.59 cy (INT64 ADD via carry chain) | default | |
| `IMAD.WIDE.U32` | ~4.53 cy | default | |
| `IMAD.WIDE.U32.X` | ~4.53 (similar) | default | |
| `IMAD.X` | ~4.53 cy | default | |
| `IMNMX` | ~4.53 cy | default | |
| `IMNMX.U32` | ~4.53 cy | default | |
| `LEA` | ~4 cy | default | |
| `LEA.HI` | ~4 cy | default | |
| `LEA.HI.SX32` | ~4 cy | default | |
| `LEA.HI.X` | ~4 cy | default | |
| `LEA.HI.X.SX32` | ~4 cy | default | |

### Integer Comparison (28 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `ISETP.EQ.AND` | ~4.53 cy | default | |
| `ISETP.EQ.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.EQ.OR` | ~4.53 cy | default | |
| `ISETP.EQ.U32.AND` | ~4.53 cy | default | |
| `ISETP.EQ.U32.AND.EX` | ~4.53 cy | default | |
| `ISETP.GE.AND` | ~4.53 cy | default | |
| `ISETP.GE.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.GE.OR` | ~4.53 cy | default | |
| `ISETP.GE.U32.AND` | ~4.53 cy | default | |
| `ISETP.GE.U32.AND.EX` | ~4.53 cy | default | |
| `ISETP.GT.AND` | ~4.53 cy | default | |
| `ISETP.GT.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.GT.U32.AND` | ~4.53 cy | default | |
| `ISETP.GT.U32.AND.EX` | ~4.53 cy | default | |
| `ISETP.GT.U32.OR` | ~4.53 cy | default | |
| `ISETP.LE.AND` | ~4.53 cy | default | |
| `ISETP.LE.U32.AND` | ~4.53 cy | default | |
| `ISETP.LE.U32.AND.EX` | ~4.53 cy | default | |
| `ISETP.LT.AND` | ~4.53 cy | default | |
| `ISETP.LT.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.LT.OR` | ~4.53 cy | default | |
| `ISETP.LT.U32.AND` | ~4.53 cy | default | |
| `ISETP.LT.U32.AND.EX` | ~4.53 cy | default | |
| `ISETP.LT.U32.OR.EX` | ~4.53 cy | default | |
| `ISETP.NE.AND` | ~4.53 cy | default | |
| `ISETP.NE.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.NE.OR` | ~4.53 cy | default | |
| `ISETP.NE.U32.AND` | ~4.53 cy | default | |

### Memory Constant (4 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDC` | 70.57 cy (constant cache chain) | default | |
| `LDC.64` | ~70 cy | default | |
| `ULDC` | ~4 cy (uniform const) | default | |
| `ULDC.64` | ~4 cy (uniform const) | default | |

### Memory Global (47 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LD.E` | ~92-123 cy | default | |
| `LD.E.128` | ~92-123 cy | default | |
| `LD.E.64` | ~92-123 cy | default | |
| `LD.E.64.STRONG.SYS` | ~92-123 cy | default | |
| `LD.E.STRONG.GPU` | ~92-123 cy | default | |
| `LD.E.STRONG.SYS` | ~92-123 cy | default | |
| `LD.E.U16` | ~92-123 cy | default | |
| `LD.E.U16.STRONG.SYS` | ~92-123 cy | default | |
| `LD.E.U8` | ~92-123 cy | default | |
| `LDG.E` | 92-123 cy (L2 hit, varies by SKU) | default | |
| `LDG.E.128` | ~92-123 (similar) | default | |
| `LDG.E.128.CONSTANT` | ~92-123 (similar) | default | |
| `LDG.E.64` | ~92-123 (similar) | default | |
| `LDG.E.64.CONSTANT` | ~92-123 (similar) | default | |
| `LDG.E.64.STRONG.SYS` | ~92-123 (similar) | default | |
| `LDG.E.CONSTANT` | ~33 cy (L1 read-only cache) | default | |
| `LDG.E.S16` | ~92-123 (similar) | default | |
| `LDG.E.S8` | ~92-123 (similar) | default | |
| `LDG.E.STRONG.SYS` | ~92-123 (similar) | default | |
| `LDG.E.U16` | ~92-123 (similar) | default | |
| `LDG.E.U16.CONSTANT` | ~92-123 (similar) | --restrict | |
| `LDG.E.U16.STRONG.SYS` | ~92-123 (similar) | default | |
| `LDG.E.U8` | ~44.99 cy (byte pointer chase) | default | |
| `LDG.E.U8.CONSTANT` | ~92-123 (similar) | --restrict | |
| `LDGDEPBAR` | ~0 cy (barrier token, not execution) | default | |
| `LDGSTS.E` | 363.28 cy/iter (async copy with sync) | default | |
| `LDGSTS.E.64.ZFILL` | ~363.28 (similar) | -G | |
| `LDGSTS.E.BYPASS.128` | ~363.28 (similar) | default | |
| `LDGSTS.E.BYPASS.128.ZFILL` | ~363.28 (similar) | -G | |
| `LDGSTS.E.ZFILL` | ~363.28 (similar) | -G | |
| `ST.E` | ~4 cy issue | default | |
| `ST.E.128` | ~4 cy issue | default | |
| `ST.E.64` | ~4 cy issue | default | |
| `ST.E.64.STRONG.SYS` | ~4 cy issue | default | |
| `ST.E.STRONG.SYS` | ~4 cy issue | default | |
| `ST.E.U16` | ~4 cy issue | default | |
| `ST.E.U16.STRONG.SYS` | ~4 cy issue | default | |
| `ST.E.U8` | ~4 cy issue | default | |
| `STG.E` | ~~4 (similar) | default | |
| `STG.E.128` | ~4 cy issue | default | |
| `STG.E.64` | ~4 cy issue | default | |
| `STG.E.64.STRONG.SYS` | ~4 cy issue | default | |
| `STG.E.EF` | ~4 cy issue (evict-first, async) | default | |
| `STG.E.STRONG.SYS` | ~4 cy issue | default | |
| `STG.E.U16` | ~4 cy issue | default | |
| `STG.E.U16.STRONG.SYS` | ~4 cy issue | default | |
| `STG.E.U8` | ~4 cy issue | default | |

### Memory Local (Spill) (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDL` | ~92 cy (LMEM spill) | -G | |
| `LDL.64` | ~92 cy (LMEM spill) | default | |
| `LDL.LU` | ~92 cy (LMEM spill) | --restrict | |
| `STL` | ~4 cy issue (spill) | --restrict / -G | |
| `STL.64` | ~4 cy issue (spill) | default | |

### Memory Shared (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDS` | 28.03 cy (shared memory) | default | |
| `LDS.128` | ~28 cy (smem) | default | |
| `LDS.64` | ~28 cy (smem) | default | |
| `STS` | ~4 cy issue (smem) | default | |
| `STS.U16` | ~4 cy issue (smem) | default | |

### Other (6 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BPT.TRAP` | ~4 cy (breakpoint) | default | Debug breakpoint trap |
| `ERRBAR` | ~4 cy | default | |
| `FRND` | ~6 cy | default | |
| `FRND.FLOOR` | ~6 cy | default | |
| `FRND.TRUNC` | ~6 cy | default | |
| `NANOSLEEP` | 2685 cy | default | |

### SFU (MUFU) (9 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MUFU.COS` | ~23.50 cy | default | |
| `MUFU.EX2` | 17.55 cy | default | |
| `MUFU.LG2` | 39.53 cy | default | |
| `MUFU.RCP` | 41.53 cy | default | |
| `MUFU.RCP64H` | 17.54 cy | default | |
| `MUFU.RSQ` | 39.53 cy | default | |
| `MUFU.RSQ64H` | ~17.54 cy (FP64 rsqrt approx) | default | |
| `MUFU.SIN` | 23.50 cy | default | |
| `MUFU.SQRT` | ~17.5 cy (only with --use_fast_math) | --use_fast_math | |

### Special Register (7 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `CS2R` | ~4 cy | default | |
| `CS2R.32` | ~4 cy | default | |
| `P2R` | ~4 cy | --use_fast_math | |
| `R2P` | ~4 cy (reg to predicate) | default | Register to predicate reload (predicate unspill) |
| `R2UR` | ~4 cy | -G | |
| `S2R` | ~4 cy | default | |
| `S2UR` | ~4 cy | default | |

### Tensor Core Integer + Data (8 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `IMMA.16816.S8.S8` | 34.06 cy/WMMA (INT8, 2x faster than float) | default | |
| `IMMA.16816.S8.S8.SAT` | ~34.06 (similar) | -G | |
| `IMMA.8832.S4.S4` | 28.05 cy/WMMA (INT4, fastest TC) | default | |
| `IMMA.8832.S4.S4.SAT` | ~28.05 (similar) | -G | |
| `IMMA.8832.U4.U4` | 28.05 cy/WMMA (=INT4 S4) | default | |
| `IMMA.8832.U4.U4.SAT` | ~28.05 (similar) | -G | |
| `LDSM.16.M88.4` | ~28 cy (shared memory matrix load) | default | |
| `MOVM.16.MT88` | ~28 cy (matrix move) | -G | |

### Texture/Surface (11 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `SULD.D.BA.1D.STRONG.SM` | ~100-200 cy | default | |
| `SULD.D.BA.1D.STRONG.SM.IGN` | ~100-200 cy | default | |
| `SULD.D.BA.1D.STRONG.SM.TRAP` | ~100-200 cy | default | |
| `SUST.D.BA.1D.STRONG.SM` | ~4 cy issue | default | |
| `SUST.D.BA.1D.STRONG.SM.IGN` | ~4 cy issue | default | |
| `SUST.D.BA.1D.STRONG.SM.TRAP` | ~4 cy issue | default | |
| `TEX.B.LL` | ~100-200 cy | default | |
| `TEX.SCR.B.LL` | ~100-200 cy | default | |
| `TEX.SCR.LL` | ~100-200 cy | default | |
| `TLD.SCR.B.LZ` | ~100-200 cy | default | |
| `TLD.SCR.LZ` | ~100-200 cy | default | |

### Uniform Datapath (12 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `UFLO.U32` | ~7-8 cy (uniform) | default | |
| `UIADD3` | ~2.5 cy (uniform) | default | |
| `UIADD3.X` | ~2.5 cy (uniform) | default | |
| `UIMAD` | ~4.5 cy (uniform) | default | |
| `UIMAD.WIDE.U32` | ~4.5 cy (uniform) | default | |
| `UISETP.GE.U32.AND` | ~4.5 cy (uniform) | --maxrregcount | |
| `UISETP.GT.AND` | ~4.5 cy (uniform) | --maxrregcount | |
| `UISETP.NE.U32.AND` | ~4.5 cy (uniform) | barrier probes | Uniform unsigned not-equal set-predicate |
| `USEL` | ~2-4 cy (uniform) | barrier probes | **Uniform conditional select** (uniform datapath equivalent of SEL) |
| `ULOP3.LUT` | ~4.5 cy (uniform) | default | |
| `UMOV` | ~2 cy (uniform) | default | |
| `UPOPC` | ~7-8 cy (uniform) | default | |
| `USHF.L.U32` | ~4.5 cy (uniform) | default | |
| `USHF.R.S32.HI` | ~4.5 cy (uniform) | default | |
| `ULEA` | ~2.5 cy (uniform pipeline) | tiling probes (-O3 --restrict) | Uniform load effective address for tile base computation. Opcode 0x7891. |

### Warp Vote/Match/Redux (7 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MATCH.ALL` | ~25 cy | default | |
| `MATCH.ANY` | ~25 cy | default | |
| `VOTE.ALL` | ~25 cy | default | |
| `VOTE.ANY` | ~25 cy | default | |
| `VOTEU.ANY` | ~25 cy | default | |
| `WARPSYNC` | ~25 cy | default | |
| `WARPSYNC.EXCLUSIVE` | ~25 cy | -G | |

---

**Total: 363 unique SASS mnemonics across 25 categories.**

All latencies measured on RTX 4070 Ti (SM 8.9, 2625 MHz, 60 SMs).
See `RESULTS.md` for measurement methodology, ncu cross-validation,
and corrected values.