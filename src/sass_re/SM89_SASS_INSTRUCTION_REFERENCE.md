# Ada Lovelace SM 8.9 SASS Instruction Reference

Definitive inventory of all 364 SASS mnemonics observed on NVIDIA Ada Lovelace
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
| `ATOM.E.ADD.64.STRONG.GPU` |  | default | |
| `ATOM.E.ADD.F32.FTZ.RN.STRONG.GPU` |  | default | |
| `ATOM.E.ADD.STRONG.GPU` |  | default | |
| `ATOM.E.AND.STRONG.GPU` |  | default | |
| `ATOM.E.CAS.STRONG.GPU` |  | default | |
| `ATOM.E.EXCH.STRONG.GPU` |  | default | |
| `ATOM.E.MAX.S32.STRONG.GPU` |  | default | |
| `ATOM.E.MIN.S32.STRONG.GPU` |  | default | |
| `ATOM.E.OR.STRONG.GPU` |  | default | |
| `ATOM.E.XOR.STRONG.GPU` |  | default | |
| `ATOMG.E.AND.STRONG.GPU` |  | default | |
| `ATOMG.E.CAS.STRONG.GPU` |  | default | |
| `ATOMG.E.EXCH.STRONG.GPU` |  | default | |
| `ATOMG.E.MAX.S32.STRONG.GPU` |  | default | |
| `ATOMG.E.MIN.S32.STRONG.GPU` |  | default | |
| `ATOMG.E.OR.STRONG.GPU` |  | default | |
| `ATOMG.E.XOR.STRONG.GPU` |  | default | |
| `RED.E.ADD.F32.FTZ.RN.STRONG.GPU` |  | default | |
| `RED.E.ADD.STRONG.GPU` |  | default | |
| `REDUX.MAX.S32` | ~60 cy | default | |
| `REDUX.MIN.S32` | ~60 cy | default | |
| `REDUX.OR` |  | default | |
| `REDUX.SUM` | 60.01 cy (2.6x faster than SHFL tree) | default | |
| `REDUX.SUM.S32` | 60.01 cy | default | |

### Atomic Shared (3 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `ATOMS.CAST.SPIN` |  | -G | |
| `ATOMS.CAST.SPIN.64` |  | -G | |
| `ATOMS.POPC.INC.32` |  | default | |

### Barrier/Sync (3 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BAR.SYNC` |  | default | |
| `BAR.SYNC.DEFER_BLOCKING` |  | default | |
| `DEPBAR.LE` |  | default | |

### Bit Manipulation (25 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BMSK` |  | -G | |
| `BREV` | 17.51 cy (SFU) | default | |
| `FLO.U32` |  | default | |
| `FLO.U32.SH` |  | default | |
| `LOP3.LUT` | 4.53 cy | default | |
| `PLOP3.LUT` |  | default | |
| `POPC` | ~7-8 cy (multi-cycle INT, corrected from 23.52) | default | |
| `PRMT` | 4.52 cy | default | |
| `SGXT` |  | default | |
| `SGXT.U32` |  | default | |
| `SHF.L.U32` | 4.52 cy | default | |
| `SHF.L.U32.HI` | ~4.52 (similar) | default | |
| `SHF.L.U64.HI` |  | default | |
| `SHF.L.W.U32` | ~4.52 cy | default | |
| `SHF.L.W.U32.HI` | ~~4.52 (similar) | default | |
| `SHF.R.S32.HI` | 4.52 cy | default | |
| `SHF.R.S64` | ~4.52 cy | default | |
| `SHF.R.U32` | ~4.52 (similar) | default | |
| `SHF.R.U32.HI` | 4.52 cy | default | |
| `SHF.R.U64` |  | default | |
| `SHF.R.W.U32` |  | default | |
| `SHFL.BFLY` | 24.96 cy | default | |
| `SHFL.DOWN` | ~24.96 cy | default | |
| `SHFL.IDX` | ~24.96 cy | default | |
| `SHFL.UP` | ~24.96 cy | default | |

### Cache Control (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `CCTL.E.PF1` |  | default | |
| `CCTL.E.PF2` |  | default | |
| `CCTL.IVALL` |  | default | |
| `QSPC.E.G` |  | -G | |
| `QSPC.E.S` |  | -G | |

### Control Flow (14 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BMOV.32` |  | -G | |
| `BMOV.32.CLEAR` |  | -G | |
| `BRA` |  | default | |
| `BRA.CONV` |  | default | |
| `BRX` |  | default | |
| `BSSY` |  | default | |
| `BSYNC` |  | default | |
| `CALL.ABS.NOINC` |  | -G | |
| `CALL.REL.NOINC` |  | default | |
| `EXIT` | ~0 cy (thread termination) | default | |
| `NOP` | 0 cy (pipeline filler) | default | |
| `RET.ABS.NODEC` |  | -G | |
| `RET.REL.NODEC` |  | default | |
| `YIELD` | 2676.61 cy (=NANOSLEEP) | default | |

### Conversion (38 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `F2F.BF16.F32` |  | default | |
| `F2F.F16.F32` |  | default | |
| `F2F.F16.F32.RM` |  | default | |
| `F2F.F16.F32.RP` |  | default | |
| `F2F.F16.F32.RZ` |  | default | |
| `F2F.F32.F64` |  | default | |
| `F2F.F64.F32` |  | default | |
| `F2FP.BF16.F32.PACK_AB` | ~8.54 cy (BF16 round-trip) | default | |
| `F2FP.F16.E4M3.UNPACK_B` | ~6 cy (FP8 decode) | default | |
| `F2FP.F16.E5M2.UNPACK_B` | ~6 cy (FP8 E5M2 decode) | default | |
| `F2FP.F16.F32.PACK_AB` | ~10.54 cy (FP16 round-trip) | default | |
| `F2FP.F16.F32.PACK_AB.RZ` | ~~10.54 (similar) | default | |
| `F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C` | ~18.54 cy (FP8 round-trip) | default | |
| `F2FP.SATFINITE.E5M2.F32.PACK_AB_MERGE_C` | ~18.53 cy (FP8 E5M2 round-trip) | default | |
| `F2I.CEIL.NTZ` |  | default | |
| `F2I.F64` |  | default | |
| `F2I.FLOOR.NTZ` |  | default | |
| `F2I.FTZ.CEIL.NTZ` |  | default | |
| `F2I.FTZ.FLOOR.NTZ` |  | default | |
| `F2I.FTZ.NTZ` |  | default | |
| `F2I.FTZ.TRUNC.NTZ` |  | default | |
| `F2I.FTZ.U32.NTZ` |  | default | |
| `F2I.FTZ.U32.TRUNC.NTZ` |  | default | |
| `F2I.NTZ` |  | default | |
| `F2I.TRUNC.NTZ` | ~12.03 cy (F2I+I2F round-trip) | default | |
| `F2I.U32.NTZ` |  | default | |
| `F2I.U32.TRUNC.NTZ` |  | default | |
| `I2F.F64` |  | default | |
| `I2F.F64.S64` |  | default | |
| `I2F.RM` |  | default | |
| `I2F.RP` |  | default | |
| `I2F.S16` | ~44.51 cy (INT16 I2F+F2I chain) | default | |
| `I2F.S8` | ~6 cy (direct byte-to-float) | --restrict | |
| `I2F.U16` |  | default | |
| `I2F.U32.RP` |  | default | |
| `I2FP.F32.S32` | ~6 cy | default | |
| `I2FP.F32.S32.RZ` | ~~6 (similar) | default | |
| `I2FP.F32.U32` |  | default | |

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
| `HMNMX2` |  | default | |
| `HMUL2` | ~4.54 cy (only with -fmad=false) | -fmad=false | |

### FP32 Arithmetic (42 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `FADD` | 4.52 cy | default | |
| `FADD.FTZ` | ~4.52 cy | default | |
| `FADD.FTZ.RZ` | ~4.52 cy | default | |
| `FADD.RZ` | ~4.52 cy | default | |
| `FADD.SAT` | 4.52 cy (SAT=FREE) | default | |
| `FCHK` |  | default | |
| `FFMA` | 4.53 cy | default | |
| `FFMA.FTZ` | 4.51 cy (FTZ=FREE) | default | |
| `FFMA.RM` | ~4.53 cy | default | |
| `FFMA.RP` | ~4.53 cy | default | |
| `FFMA.RZ` | ~4.53 cy | default | |
| `FFMA.SAT` | ~4.53 (similar) | default | |
| `FMNMX` |  | default | |
| `FMNMX.FTZ` |  | default | |
| `FMUL` | 4.52 cy | default | |
| `FMUL.D8` | ~4.52 (similar) | default | |
| `FMUL.FTZ` | ~4.52 (similar) | default | |
| `FMUL.FTZ.D8` | ~4.52 cy | default | |
| `FMUL.RZ` | ~4.52 (similar) | default | |
| `FMUL.SAT` | ~4.52 (similar) | default | |
| `FSEL` | 8.52 cy | default | |
| `FSET.BF.GT.AND` |  | default | |
| `FSET.BF.GT.FTZ.AND` |  | default | |
| `FSETP.EQ.AND` |  | default | |
| `FSETP.EQ.FTZ.AND` |  | default | |
| `FSETP.EQ.OR` |  | default | |
| `FSETP.GE.AND` | ~8.52 cy | default | |
| `FSETP.GE.FTZ.AND` |  | default | |
| `FSETP.GEU.AND` |  | default | |
| `FSETP.GEU.FTZ.AND` |  | default | |
| `FSETP.GEU.OR` |  | default | |
| `FSETP.GT.AND` | ~8.52 cy | default | |
| `FSETP.GT.FTZ.AND` |  | default | |
| `FSETP.GTU.AND` |  | default | |
| `FSETP.GTU.FTZ.AND` | ~8.52 cy | default | |
| `FSETP.GTU.OR` |  | default | |
| `FSETP.LE.AND` |  | default | |
| `FSETP.LE.FTZ.AND` |  | default | |
| `FSETP.LT.AND` |  | default | |
| `FSETP.LT.FTZ.AND` |  | default | |
| `FSETP.NEU.AND` | ~8.52 cy | default | |
| `FSETP.NEU.FTZ.AND` |  | default | |

### FP64 Arithmetic (19 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `DADD` | 48.47 cy | default | |
| `DFMA` | 54.48 cy | default | |
| `DFMA.RM` | ~54.48 (similar) | default | |
| `DFMA.RP` | ~54.48 (similar) | default | |
| `DMUL` | 48.47 cy | default | |
| `DMUL.RP` | ~48.47 (similar) | default | |
| `DSETP.EQ.AND` |  | default | |
| `DSETP.EQU.AND` |  | default | |
| `DSETP.GE.AND` |  | default | |
| `DSETP.GEU.AND` |  | default | |
| `DSETP.GT.AND` | ~38 cy | default | |
| `DSETP.GTU.AND` | ~38 cy | default | |
| `DSETP.LE.AND` |  | default | |
| `DSETP.LT.AND` |  | default | |
| `DSETP.MAX.AND` |  | default | |
| `DSETP.MIN.AND` |  | default | |
| `DSETP.NAN.AND` |  | default | |
| `DSETP.NE.AND` |  | default | |
| `DSETP.NEU.AND` |  | default | |

### Fence (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MEMBAR.ALL.GPU` | 205.25 cy (__threadfence) | default | |
| `MEMBAR.SC.CTA` |  | default | |
| `MEMBAR.SC.GPU` |  | default | |
| `MEMBAR.SC.SYS` | 2583.37 cy (system-scope) | default | |
| `MEMBAR.SC.VC` |  | -G | |

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
| `LEA` |  | default | |
| `LEA.HI` |  | default | |
| `LEA.HI.SX32` |  | default | |
| `LEA.HI.X` |  | default | |
| `LEA.HI.X.SX32` |  | default | |

### Integer Comparison (28 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `ISETP.EQ.AND` | ~4.53 cy | default | |
| `ISETP.EQ.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.EQ.OR` |  | default | |
| `ISETP.EQ.U32.AND` |  | default | |
| `ISETP.EQ.U32.AND.EX` |  | default | |
| `ISETP.GE.AND` | ~4.53 cy | default | |
| `ISETP.GE.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.GE.OR` |  | default | |
| `ISETP.GE.U32.AND` |  | default | |
| `ISETP.GE.U32.AND.EX` |  | default | |
| `ISETP.GT.AND` | ~4.53 cy | default | |
| `ISETP.GT.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.GT.U32.AND` |  | default | |
| `ISETP.GT.U32.AND.EX` |  | default | |
| `ISETP.GT.U32.OR` |  | default | |
| `ISETP.LE.AND` |  | default | |
| `ISETP.LE.U32.AND` |  | default | |
| `ISETP.LE.U32.AND.EX` |  | default | |
| `ISETP.LT.AND` | ~4.53 cy | default | |
| `ISETP.LT.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.LT.OR` |  | default | |
| `ISETP.LT.U32.AND` |  | default | |
| `ISETP.LT.U32.AND.EX` |  | default | |
| `ISETP.LT.U32.OR.EX` |  | default | |
| `ISETP.NE.AND` | ~4.53 cy | default | |
| `ISETP.NE.AND.EX` | ~~4.53 (similar) | default | |
| `ISETP.NE.OR` |  | default | |
| `ISETP.NE.U32.AND` |  | default | |

### Memory Constant (4 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDC` | 70.57 cy (constant cache chain) | default | |
| `LDC.64` |  | default | |
| `ULDC` |  | default | |
| `ULDC.64` |  | default | |

### Memory Global (47 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LD.E` |  | default | |
| `LD.E.128` |  | default | |
| `LD.E.64` |  | default | |
| `LD.E.64.STRONG.SYS` |  | default | |
| `LD.E.STRONG.GPU` |  | default | |
| `LD.E.STRONG.SYS` |  | default | |
| `LD.E.U16` |  | default | |
| `LD.E.U16.STRONG.SYS` |  | default | |
| `LD.E.U8` |  | default | |
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
| `ST.E` |  | default | |
| `ST.E.128` |  | default | |
| `ST.E.64` |  | default | |
| `ST.E.64.STRONG.SYS` |  | default | |
| `ST.E.STRONG.SYS` |  | default | |
| `ST.E.U16` |  | default | |
| `ST.E.U16.STRONG.SYS` |  | default | |
| `ST.E.U8` |  | default | |
| `STG.E` | ~~4 (similar) | default | |
| `STG.E.128` |  | default | |
| `STG.E.64` |  | default | |
| `STG.E.64.STRONG.SYS` |  | default | |
| `STG.E.EF` | ~4 cy issue (evict-first, async) | default | |
| `STG.E.STRONG.SYS` |  | default | |
| `STG.E.U16` |  | default | |
| `STG.E.U16.STRONG.SYS` |  | default | |
| `STG.E.U8` |  | default | |

### Memory Local (Spill) (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDL` |  | -G | |
| `LDL.64` |  | default | |
| `LDL.LU` |  | --restrict | |
| `STL` |  | --restrict / -G | |
| `STL.64` |  | default | |

### Memory Shared (5 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `LDS` | 28.03 cy (shared memory) | default | |
| `LDS.128` |  | default | |
| `LDS.64` |  | default | |
| `STS` |  | default | |
| `STS.U16` |  | default | |

### Other (6 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `BPT.TRAP` |  | default | |
| `ERRBAR` |  | default | |
| `FRND` |  | default | |
| `FRND.FLOOR` |  | default | |
| `FRND.TRUNC` |  | default | |
| `NANOSLEEP` |  | default | |

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
| `CS2R` |  | default | |
| `CS2R.32` |  | default | |
| `P2R` |  | --use_fast_math | |
| `R2P` |  | default | |
| `R2UR` |  | -G | |
| `S2R` |  | default | |
| `S2UR` |  | default | |

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
| `MOVM.16.MT88` |  | -G | |

### Texture/Surface (11 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `SULD.D.BA.1D.STRONG.SM` |  | default | |
| `SULD.D.BA.1D.STRONG.SM.IGN` |  | default | |
| `SULD.D.BA.1D.STRONG.SM.TRAP` |  | default | |
| `SUST.D.BA.1D.STRONG.SM` |  | default | |
| `SUST.D.BA.1D.STRONG.SM.IGN` |  | default | |
| `SUST.D.BA.1D.STRONG.SM.TRAP` |  | default | |
| `TEX.B.LL` |  | default | |
| `TEX.SCR.B.LL` |  | default | |
| `TEX.SCR.LL` |  | default | |
| `TLD.SCR.B.LZ` |  | default | |
| `TLD.SCR.LZ` |  | default | |

### Uniform Datapath (12 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `UFLO.U32` |  | default | |
| `UIADD3` |  | default | |
| `UIADD3.X` |  | default | |
| `UIMAD` |  | default | |
| `UIMAD.WIDE.U32` |  | default | |
| `UISETP.GE.U32.AND` |  | --maxrregcount | |
| `UISETP.GT.AND` |  | --maxrregcount | |
| `ULOP3.LUT` |  | default | |
| `UMOV` |  | default | |
| `UPOPC` |  | default | |
| `USHF.L.U32` |  | default | |
| `USHF.R.S32.HI` |  | default | |
| `ULEA` | ~2.5 cy (uniform pipeline) | tiling probes (-O3 --restrict) | Uniform load effective address for tile base computation. Opcode 0x7891. |

### Warp Vote/Match/Redux (7 mnemonics)

| Mnemonic | Measured Latency | Flags | Notes |
|---|---|---|---|
| `MATCH.ALL` | ~25 cy | default | |
| `MATCH.ANY` |  | default | |
| `VOTE.ALL` |  | default | |
| `VOTE.ANY` |  | default | |
| `VOTEU.ANY` |  | default | |
| `WARPSYNC` |  | default | |
| `WARPSYNC.EXCLUSIVE` |  | -G | |

---

**Total: 363 unique SASS mnemonics across 25 categories.**

All latencies measured on RTX 4070 Ti (SM 8.9, 2625 MHz, 60 SMs).
See `RESULTS.md` for measurement methodology, ncu cross-validation,
and corrected values.