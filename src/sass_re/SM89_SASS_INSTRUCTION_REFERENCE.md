# Ada Lovelace SM 8.9 SASS Instruction Reference

Definitive inventory of all SASS mnemonics observed on NVIDIA Ada Lovelace
SM 8.9 (RTX 4070 Ti) across 61 probe kernels compiled with 20 flag
combinations (1200 total compilations).

**363 unique SASS mnemonics** documented below, categorized by functional unit.

- Generated: 2026-03-19
- Hardware: NVIDIA GeForce RTX 4070 Ti (AD104, SM 8.9, 60 SMs)
- Compiler: CUDA 13.1 (nvcc V13.1.115)
- Probes: 61 files in `src/sass_re/probes/`
- Microbenchmarks: 13 files in `src/sass_re/microbench/`
- Flags tested: default, -O1, -O2, -O3, --use_fast_math, --restrict,
  -fmad=false, --maxrregcount=32/64/128/255, -G, --prec-div=true,
  --prec-sqrt=true, -ftz=false, --extra-device-vectorization,
  --default-stream per-thread, -Xptxas -warn-spills, -warn-double-usage

See `RESULTS.md` for latency measurements and analysis.

---


### Atomic Global (24)

| Mnemonic | Flags that emit it |
|---|---|
| `ATOM.E.ADD.64.STRONG.GPU` | |
| `ATOM.E.ADD.F32.FTZ.RN.STRONG.GPU` | |
| `ATOM.E.ADD.STRONG.GPU` | |
| `ATOM.E.AND.STRONG.GPU` | |
| `ATOM.E.CAS.STRONG.GPU` | |
| `ATOM.E.EXCH.STRONG.GPU` | |
| `ATOM.E.MAX.S32.STRONG.GPU` | |
| `ATOM.E.MIN.S32.STRONG.GPU` | |
| `ATOM.E.OR.STRONG.GPU` | |
| `ATOM.E.XOR.STRONG.GPU` | |
| `ATOMG.E.AND.STRONG.GPU` | |
| `ATOMG.E.CAS.STRONG.GPU` | |
| `ATOMG.E.EXCH.STRONG.GPU` | |
| `ATOMG.E.MAX.S32.STRONG.GPU` | |
| `ATOMG.E.MIN.S32.STRONG.GPU` | |
| `ATOMG.E.OR.STRONG.GPU` | |
| `ATOMG.E.XOR.STRONG.GPU` | |
| `RED.E.ADD.F32.FTZ.RN.STRONG.GPU` | |
| `RED.E.ADD.STRONG.GPU` | |
| `REDUX.MAX.S32` | |
| `REDUX.MIN.S32` | |
| `REDUX.OR` | |
| `REDUX.SUM` | |
| `REDUX.SUM.S32` | |

### Atomic Shared (3)

| Mnemonic | Flags that emit it |
|---|---|
| `ATOMS.CAST.SPIN` | |
| `ATOMS.CAST.SPIN.64` | |
| `ATOMS.POPC.INC.32` | |

### Barrier/Sync (3)

| Mnemonic | Flags that emit it |
|---|---|
| `BAR.SYNC` | |
| `BAR.SYNC.DEFER_BLOCKING` | |
| `DEPBAR.LE` | |

### Bit Manipulation (25)

| Mnemonic | Flags that emit it |
|---|---|
| `BMSK` | |
| `BREV` | |
| `FLO.U32` | |
| `FLO.U32.SH` | |
| `LOP3.LUT` | |
| `PLOP3.LUT` | |
| `POPC` | |
| `PRMT` | |
| `SGXT` | |
| `SGXT.U32` | |
| `SHF.L.U32` | |
| `SHF.L.U32.HI` | |
| `SHF.L.U64.HI` | |
| `SHF.L.W.U32` | |
| `SHF.L.W.U32.HI` | |
| `SHF.R.S32.HI` | |
| `SHF.R.S64` | |
| `SHF.R.U32` | |
| `SHF.R.U32.HI` | |
| `SHF.R.U64` | |
| `SHF.R.W.U32` | |
| `SHFL.BFLY` | |
| `SHFL.DOWN` | |
| `SHFL.IDX` | |
| `SHFL.UP` | |

### Cache Control (5)

| Mnemonic | Flags that emit it |
|---|---|
| `CCTL.E.PF1` | |
| `CCTL.E.PF2` | |
| `CCTL.IVALL` | |
| `QSPC.E.G` | |
| `QSPC.E.S` | |

### Control Flow (14)

| Mnemonic | Flags that emit it |
|---|---|
| `BMOV.32` | |
| `BMOV.32.CLEAR` | |
| `BRA` | |
| `BRA.CONV` | |
| `BRX` | |
| `BSSY` | |
| `BSYNC` | |
| `CALL.ABS.NOINC` | |
| `CALL.REL.NOINC` | |
| `EXIT` | |
| `NOP` | |
| `RET.ABS.NODEC` | |
| `RET.REL.NODEC` | |
| `YIELD` | |

### Conversion (38)

| Mnemonic | Flags that emit it |
|---|---|
| `F2F.BF16.F32` | |
| `F2F.F16.F32` | |
| `F2F.F16.F32.RM` | |
| `F2F.F16.F32.RP` | |
| `F2F.F16.F32.RZ` | |
| `F2F.F32.F64` | |
| `F2F.F64.F32` | |
| `F2FP.BF16.F32.PACK_AB` | |
| `F2FP.F16.E4M3.UNPACK_B` | |
| `F2FP.F16.E5M2.UNPACK_B` | |
| `F2FP.F16.F32.PACK_AB` | |
| `F2FP.F16.F32.PACK_AB.RZ` | |
| `F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C` | |
| `F2FP.SATFINITE.E5M2.F32.PACK_AB_MERGE_C` | |
| `F2I.CEIL.NTZ` | |
| `F2I.F64` | |
| `F2I.FLOOR.NTZ` | |
| `F2I.FTZ.CEIL.NTZ` | |
| `F2I.FTZ.FLOOR.NTZ` | |
| `F2I.FTZ.NTZ` | |
| `F2I.FTZ.TRUNC.NTZ` | |
| `F2I.FTZ.U32.NTZ` | |
| `F2I.FTZ.U32.TRUNC.NTZ` | |
| `F2I.NTZ` | |
| `F2I.TRUNC.NTZ` | |
| `F2I.U32.NTZ` | |
| `F2I.U32.TRUNC.NTZ` | |
| `I2F.F64` | |
| `I2F.F64.S64` | |
| `I2F.RM` | |
| `I2F.RP` | |
| `I2F.S16` | |
| `I2F.S8` | |
| `I2F.U16` | |
| `I2F.U32.RP` | |
| `I2FP.F32.S32` | |
| `I2FP.F32.S32.RZ` | |
| `I2FP.F32.U32` | |

### Data Movement (2)

| Mnemonic | Flags that emit it |
|---|---|
| `MOV` | |
| `SEL` | |

### FP16/BF16 Packed + TC (10)

| Mnemonic | Flags that emit it |
|---|---|
| `HADD2` | |
| `HADD2.F32` | |
| `HFMA2` | |
| `HFMA2.BF16_V2` | |
| `HMMA.16816.F16` | |
| `HMMA.16816.F32` | |
| `HMMA.16816.F32.BF16` | |
| `HMMA.1684.F32.TF32` | |
| `HMNMX2` | |
| `HMUL2` | |

### FP32 Arithmetic (42)

| Mnemonic | Flags that emit it |
|---|---|
| `FADD` | |
| `FADD.FTZ` | |
| `FADD.FTZ.RZ` | |
| `FADD.RZ` | |
| `FADD.SAT` | |
| `FCHK` | |
| `FFMA` | |
| `FFMA.FTZ` | |
| `FFMA.RM` | |
| `FFMA.RP` | |
| `FFMA.RZ` | |
| `FFMA.SAT` | |
| `FMNMX` | |
| `FMNMX.FTZ` | |
| `FMUL` | |
| `FMUL.D8` | |
| `FMUL.FTZ` | |
| `FMUL.FTZ.D8` | |
| `FMUL.RZ` | |
| `FMUL.SAT` | |
| `FSEL` | |
| `FSET.BF.GT.AND` | |
| `FSET.BF.GT.FTZ.AND` | |
| `FSETP.EQ.AND` | |
| `FSETP.EQ.FTZ.AND` | |
| `FSETP.EQ.OR` | |
| `FSETP.GE.AND` | |
| `FSETP.GE.FTZ.AND` | |
| `FSETP.GEU.AND` | |
| `FSETP.GEU.FTZ.AND` | |
| `FSETP.GEU.OR` | |
| `FSETP.GT.AND` | |
| `FSETP.GT.FTZ.AND` | |
| `FSETP.GTU.AND` | |
| `FSETP.GTU.FTZ.AND` | |
| `FSETP.GTU.OR` | |
| `FSETP.LE.AND` | |
| `FSETP.LE.FTZ.AND` | |
| `FSETP.LT.AND` | |
| `FSETP.LT.FTZ.AND` | |
| `FSETP.NEU.AND` | |
| `FSETP.NEU.FTZ.AND` | |

### FP64 Arithmetic (19)

| Mnemonic | Flags that emit it |
|---|---|
| `DADD` | |
| `DFMA` | |
| `DFMA.RM` | |
| `DFMA.RP` | |
| `DMUL` | |
| `DMUL.RP` | |
| `DSETP.EQ.AND` | |
| `DSETP.EQU.AND` | |
| `DSETP.GE.AND` | |
| `DSETP.GEU.AND` | |
| `DSETP.GT.AND` | |
| `DSETP.GTU.AND` | |
| `DSETP.LE.AND` | |
| `DSETP.LT.AND` | |
| `DSETP.MAX.AND` | |
| `DSETP.MIN.AND` | |
| `DSETP.NAN.AND` | |
| `DSETP.NE.AND` | |
| `DSETP.NEU.AND` | |

### Fence (5)

| Mnemonic | Flags that emit it |
|---|---|
| `MEMBAR.ALL.GPU` | |
| `MEMBAR.SC.CTA` | |
| `MEMBAR.SC.GPU` | |
| `MEMBAR.SC.SYS` | |
| `MEMBAR.SC.VC` | |

### Integer Arithmetic (24)

| Mnemonic | Flags that emit it |
|---|---|
| `IABS` | |
| `IADD3` | |
| `IADD3.X` | |
| `IDP.4A.S8.S8` | |
| `IMAD` | |
| `IMAD.HI` | |
| `IMAD.HI.U32` | |
| `IMAD.IADD` | |
| `IMAD.MOV` | |
| `IMAD.MOV.U32` | |
| `IMAD.SHL` | |
| `IMAD.SHL.U32` | |
| `IMAD.U32` | |
| `IMAD.WIDE` | |
| `IMAD.WIDE.U32` | |
| `IMAD.WIDE.U32.X` | |
| `IMAD.X` | |
| `IMNMX` | |
| `IMNMX.U32` | |
| `LEA` | |
| `LEA.HI` | |
| `LEA.HI.SX32` | |
| `LEA.HI.X` | |
| `LEA.HI.X.SX32` | |

### Integer Comparison (28)

| Mnemonic | Flags that emit it |
|---|---|
| `ISETP.EQ.AND` | |
| `ISETP.EQ.AND.EX` | |
| `ISETP.EQ.OR` | |
| `ISETP.EQ.U32.AND` | |
| `ISETP.EQ.U32.AND.EX` | |
| `ISETP.GE.AND` | |
| `ISETP.GE.AND.EX` | |
| `ISETP.GE.OR` | |
| `ISETP.GE.U32.AND` | |
| `ISETP.GE.U32.AND.EX` | |
| `ISETP.GT.AND` | |
| `ISETP.GT.AND.EX` | |
| `ISETP.GT.U32.AND` | |
| `ISETP.GT.U32.AND.EX` | |
| `ISETP.GT.U32.OR` | |
| `ISETP.LE.AND` | |
| `ISETP.LE.U32.AND` | |
| `ISETP.LE.U32.AND.EX` | |
| `ISETP.LT.AND` | |
| `ISETP.LT.AND.EX` | |
| `ISETP.LT.OR` | |
| `ISETP.LT.U32.AND` | |
| `ISETP.LT.U32.AND.EX` | |
| `ISETP.LT.U32.OR.EX` | |
| `ISETP.NE.AND` | |
| `ISETP.NE.AND.EX` | |
| `ISETP.NE.OR` | |
| `ISETP.NE.U32.AND` | |

### Memory Constant (4)

| Mnemonic | Flags that emit it |
|---|---|
| `LDC` | |
| `LDC.64` | |
| `ULDC` | |
| `ULDC.64` | |

### Memory Global (47)

| Mnemonic | Flags that emit it |
|---|---|
| `LD.E` | |
| `LD.E.128` | |
| `LD.E.64` | |
| `LD.E.64.STRONG.SYS` | |
| `LD.E.STRONG.GPU` | |
| `LD.E.STRONG.SYS` | |
| `LD.E.U16` | |
| `LD.E.U16.STRONG.SYS` | |
| `LD.E.U8` | |
| `LDG.E` | |
| `LDG.E.128` | |
| `LDG.E.128.CONSTANT` | |
| `LDG.E.64` | |
| `LDG.E.64.CONSTANT` | |
| `LDG.E.64.STRONG.SYS` | |
| `LDG.E.CONSTANT` | |
| `LDG.E.S16` | |
| `LDG.E.S8` | |
| `LDG.E.STRONG.SYS` | |
| `LDG.E.U16` | |
| `LDG.E.U16.CONSTANT` | |
| `LDG.E.U16.STRONG.SYS` | |
| `LDG.E.U8` | |
| `LDG.E.U8.CONSTANT` | |
| `LDGDEPBAR` | |
| `LDGSTS.E` | |
| `LDGSTS.E.64.ZFILL` | |
| `LDGSTS.E.BYPASS.128` | |
| `LDGSTS.E.BYPASS.128.ZFILL` | |
| `LDGSTS.E.ZFILL` | |
| `ST.E` | |
| `ST.E.128` | |
| `ST.E.64` | |
| `ST.E.64.STRONG.SYS` | |
| `ST.E.STRONG.SYS` | |
| `ST.E.U16` | |
| `ST.E.U16.STRONG.SYS` | |
| `ST.E.U8` | |
| `STG.E` | |
| `STG.E.128` | |
| `STG.E.64` | |
| `STG.E.64.STRONG.SYS` | |
| `STG.E.EF` | |
| `STG.E.STRONG.SYS` | |
| `STG.E.U16` | |
| `STG.E.U16.STRONG.SYS` | |
| `STG.E.U8` | |

### Memory Local (Spill) (5)

| Mnemonic | Flags that emit it |
|---|---|
| `LDL` | |
| `LDL.64` | |
| `LDL.LU` | |
| `STL` | |
| `STL.64` | |

### Memory Shared (6)

| Mnemonic | Flags that emit it |
|---|---|
| `LDS` | |
| `LDS.128` | |
| `LDS.64` | |
| `LDSM.16.M88.4` | |
| `STS` | |
| `STS.U16` | |

### Other (6)

| Mnemonic | Flags that emit it |
|---|---|
| `BPT.TRAP` | |
| `ERRBAR` | |
| `FRND` | |
| `FRND.FLOOR` | |
| `FRND.TRUNC` | |
| `NANOSLEEP` | |

### SFU (MUFU) (9)

| Mnemonic | Flags that emit it |
|---|---|
| `MUFU.COS` | |
| `MUFU.EX2` | |
| `MUFU.LG2` | |
| `MUFU.RCP` | |
| `MUFU.RCP64H` | |
| `MUFU.RSQ` | |
| `MUFU.RSQ64H` | |
| `MUFU.SIN` | |
| `MUFU.SQRT` | |

### Special Register (7)

| Mnemonic | Flags that emit it |
|---|---|
| `CS2R` | |
| `CS2R.32` | |
| `P2R` | |
| `R2P` | |
| `R2UR` | |
| `S2R` | |
| `S2UR` | |

### Tensor Core Data (1)

| Mnemonic | Flags that emit it |
|---|---|
| `MOVM.16.MT88` | |

### Tensor Core INT (6)

| Mnemonic | Flags that emit it |
|---|---|
| `IMMA.16816.S8.S8` | |
| `IMMA.16816.S8.S8.SAT` | |
| `IMMA.8832.S4.S4` | |
| `IMMA.8832.S4.S4.SAT` | |
| `IMMA.8832.U4.U4` | |
| `IMMA.8832.U4.U4.SAT` | |

### Texture/Surface (11)

| Mnemonic | Flags that emit it |
|---|---|
| `SULD.D.BA.1D.STRONG.SM` | |
| `SULD.D.BA.1D.STRONG.SM.IGN` | |
| `SULD.D.BA.1D.STRONG.SM.TRAP` | |
| `SUST.D.BA.1D.STRONG.SM` | |
| `SUST.D.BA.1D.STRONG.SM.IGN` | |
| `SUST.D.BA.1D.STRONG.SM.TRAP` | |
| `TEX.B.LL` | |
| `TEX.SCR.B.LL` | |
| `TEX.SCR.LL` | |
| `TLD.SCR.B.LZ` | |
| `TLD.SCR.LZ` | |

### Uniform Datapath (12)

| Mnemonic | Flags that emit it |
|---|---|
| `UFLO.U32` | |
| `UIADD3` | |
| `UIADD3.X` | |
| `UIMAD` | |
| `UIMAD.WIDE.U32` | |
| `UISETP.GE.U32.AND` | |
| `UISETP.GT.AND` | |
| `ULOP3.LUT` | |
| `UMOV` | |
| `UPOPC` | |
| `USHF.L.U32` | |
| `USHF.R.S32.HI` | |

### Warp Vote/Match/Redux (7)

| Mnemonic | Flags that emit it |
|---|---|
| `MATCH.ALL` | |
| `MATCH.ANY` | |
| `VOTE.ALL` | |
| `VOTE.ANY` | |
| `VOTEU.ANY` | |
| `WARPSYNC` | |
| `WARPSYNC.EXCLUSIVE` | |

---

**Total: 363 unique SASS mnemonics.**
