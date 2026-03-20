# Ada Lovelace SM 8.9 SASS Instruction Reference

Definitive inventory of all 443 SASS mnemonics observed on NVIDIA Ada Lovelace
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

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `ATOM.E.ADD.64.STRONG.GPU` |  | atomicAdd(global) | default | |
| `ATOMG.E.ADD.STRONG.GPU` |  | atomicXxx_system() | barrier probes (-O3 --restrict) | Global atomic add with strong ordering (G = global scope) |
| `ATOM.E.ADD.F32.FTZ.RN.STRONG.GPU` |  | atomicAdd(global) | default | |
| `ATOM.E.ADD.STRONG.GPU` |  | atomicAdd(global) | default | |
| `ATOM.E.AND.STRONG.GPU` |  |  | default | |
| `ATOM.E.CAS.STRONG.GPU` |  |  | default | |
| `ATOM.E.EXCH.STRONG.GPU` |  |  | default | |
| `ATOM.E.MAX.S32.STRONG.GPU` |  |  | default | |
| `ATOM.E.MIN.S32.STRONG.GPU` |  |  | default | |
| `ATOM.E.OR.STRONG.GPU` |  |  | default | |
| `ATOM.E.XOR.STRONG.GPU` |  |  | default | |
| `ATOMG.E.AND.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOM.E.CAS.64.STRONG.GPU` |  |  | -G debug + expanded probes | 64-bit global CAS with strong GPU ordering |
| `ATOMG.E.CAS.64.STRONG.GPU` |  | atomicXxx_system() | edge atomics probes | **64-bit global CAS with strong ordering.** For lock-free double-precision shared atomic accumulation. |
| `ATOMG.E.CAS.STRONG.SYS` |  | atomicXxx_system() | system-scope probes | **System-scope CAS** (cross-GPU/CPU visible atomics) |
| `ATOMG.E.EXCH.STRONG.SYS` |  | atomicXxx_system() | system-scope probes | **System-scope exchange** (CPU-visible atomic swap) |
| `ATOMG.E.CAS.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOMG.E.EXCH.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOMG.E.MAX.S32.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOMG.E.MIN.S32.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOMG.E.OR.STRONG.GPU` |  | atomicXxx_system() | default | |
| `ATOMG.E.XOR.STRONG.GPU` |  | atomicXxx_system() | default | |
| `RED.E.ADD.64.STRONG.GPU` |  | atomicAdd() [reduction, no return] | shared atomics probes | 64-bit global reduction add with strong memory ordering |
| `RED.E.ADD.F32.FTZ.RN.STRONG.GPU` |  | atomicAdd() [reduction, no return] | default | |
| `RED.E.ADD.STRONG.GPU` |  | atomicAdd() [reduction, no return] | default | |
| `RED.E.MAX.S32.STRONG.GPU` |  | atomicAdd() [reduction, no return] | shared atomics probes | Global reduction max (signed INT32, strong ordering) |
| `RED.E.ADD.F32.FTZ.RN.STRONG.SYS` |  | atomicAdd() [reduction, no return] | system-scope probes | **System-scope float reduction** (cross-GPU/CPU visible FP32 atomicAdd) |
| `RED.E.DEC.STRONG.GPU` |  | atomicAdd() [reduction, no return] | atomic sweep probes | **Global reduction wrapping decrement** with strong ordering |
| `RED.E.INC.STRONG.GPU` |  | atomicAdd() [reduction, no return] | atomic sweep probes | **Global reduction wrapping increment** with strong ordering |
| `RED.E.MIN.S32.STRONG.GPU` |  | atomicAdd() [reduction, no return] | shared atomics probes | Global reduction min (signed INT32, strong ordering) |
| `REDUX` |  |  | shared atomics probes | Bare warp reduction (no type suffix, compiler-selected) |
| `REDUX.MAX` |  | __reduce_max_sync() | atomic sweep probes | Warp-level max (bare, without .S32 suffix) |
| `REDUX.MIN` |  | __reduce_min_sync() | atomic sweep probes | Warp-level min (bare, without .S32 suffix) |
| `REDUX.MAX.S32` | ~60 cy | __reduce_max_sync() | default | |
| `REDUX.MIN.S32` | ~60 cy | __reduce_min_sync() | default | |
| `REDUX.OR` |  | __reduce_or_sync() | default | |
| `REDUX.SUM` | 60.01 cy (2.6x faster than SHFL tree) | __reduce_add_sync() | default | |
| `REDUX.SUM.S32` | 60.01 cy | __reduce_add_sync() | default | |
| `REDUX.XOR` |  | asm redux.sync.xor | shared atomics probes | **Warp-level XOR reduction.** Single-instruction bitwise parity across 32 lanes. Enables warp-wide parity/checksum in 1 cycle. Not ADD/MIN/MAX -- bitwise XOR fold. |
| `ATOM.E.ADD.64.STRONG.SYS` |  | atomicAdd_system(u64) | -G debug | 64-bit system-scope atomic add |
| `ATOM.E.ADD.F32.FTZ.RN.STRONG.SYS` |  | atomicAdd_system(float) | -G debug | System-scope FP32 atomic add with FTZ |
| `ATOM.E.ADD.STRONG.SYS` |  | atomicAdd_system(int) | -G debug | System-scope INT32 atomic add |
| `ATOM.E.AND.STRONG.SYS` |  | atomicAnd_system() | -G debug | System-scope bitwise AND |
| `ATOM.E.CAS.STRONG.SYS` |  | atomicCAS_system() | -G debug | System-scope compare-and-swap |
| `ATOM.E.DEC.STRONG.GPU` |  | atomicDec(global) | -G debug | Global wrapping decrement with GPU ordering |
| `ATOM.E.EXCH.STRONG.SYS` |  | atomicExch_system() | -G debug | System-scope exchange |
| `ATOM.E.INC.STRONG.GPU` |  | atomicInc(global) | -G debug | Global wrapping increment with GPU ordering |
| `ATOM.E.MAX.S32.STRONG.SYS` |  | atomicMax_system(int) | -G debug | System-scope signed max |
| `ATOM.E.MAX.STRONG.GPU` |  | atomicMax(unsigned,global) | -G debug | Unsigned max with GPU ordering |
| `ATOM.E.MAX.STRONG.SYS` |  | atomicMax_system(unsigned) | -G debug | System-scope unsigned max |
| `ATOM.E.MIN.S32.STRONG.SYS` |  | atomicMin_system(int) | -G debug | System-scope signed min |
| `ATOM.E.MIN.STRONG.GPU` |  | atomicMin(unsigned,global) | -G debug | Unsigned min with GPU ordering |
| `ATOM.E.MIN.STRONG.SYS` |  | atomicMin_system(unsigned) | -G debug | System-scope unsigned min |
| `ATOM.E.OR.STRONG.SYS` |  | atomicOr_system() | -G debug | System-scope bitwise OR |
| `ATOM.E.XOR.STRONG.SYS` |  | atomicXor_system() | -G debug | System-scope bitwise XOR |
| `RED.E.ADD.S32.STRONG.GPU` |  | atomicAdd(global) [red path] | -G debug | Signed INT32 reduction add |
| `RED.E.ADD.S32.STRONG.SYS` |  | atomicAdd_system() [red path] | -G debug | System-scope signed reduction add |
| `RED.E.AND.STRONG.GPU` |  | atomicAnd(global) [red path] | -G debug | Reduction AND (no return value) |
| `RED.E.MAX.S32.STRONG.SYS` |  | atomicMax_system() [red] | -G debug | System-scope reduction max |
| `RED.E.MIN.S32.STRONG.SYS` |  | atomicMin_system() [red] | -G debug | System-scope reduction min |
| `RED.E.MIN.STRONG.GPU` |  | atomicMin(unsigned) [red] | -G debug | Unsigned reduction min |
| `RED.E.OR.STRONG.GPU` |  | atomicOr(global) [red path] | -G debug | Reduction OR (no return value) |
| `RED.E.XOR.STRONG.GPU` |  | atomicXor(global) [red path] | -G debug | Reduction XOR (no return value) |

### Atomic Shared (7 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `ATOMS.CAS` |  | atomicCAS(shared) | shared atomics probes | **Shared memory compare-and-swap (32-bit).** Used for lock-free CAS loops on smem. Generates ATOMS.CAS instruction (distinct from ATOM.E.CAS for global). |
| `ATOMS.CAS.64` |  | atomicCAS(shared) | shared atomics probes | **Shared memory 64-bit CAS.** For 64-bit lock-free updates in smem. |
| `ATOMS.CAST.SPIN` |  | atomicCAS(shared) | -G | Debug spin-lock CAS loop |
| `ATOMS.CAST.SPIN.64` |  | atomicCAS(shared) | -G | Debug 64-bit spin-lock |
| `ATOMS.DEC` |  | atomicDec(shared) | atomic sweep probes | **Shared memory wrapping decrement.** atomicDec: (old==0 or old>limit) ? limit : old-1. |
| `ATOMS.EXCH` |  | atomicExch(shared) | shared atomics probes | **Shared memory exchange.** Atomically replaces smem value, returns old value. |
| `ATOMS.INC` |  | atomicInc(shared) | atomic sweep probes | **Shared memory wrapping increment.** atomicInc: (old>=limit) ? 0 : old+1. |
| `ATOMS.MIN.S32` | 4.37 cy (single thread) | atomicMin(shared) | atomic sweep probes | **Shared memory signed minimum.** Nearly same latency as ATOMS.ADD (4.27 cy). |
| `ATOMS.POPC.INC.32` |  |  | default | |

### Barrier/Sync (3 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `BAR.ARV` |  | bar.arrive (PTX) | barrier probes (-O3 --restrict) | **Split-phase arrive-without-wait.** Thread signals arrival but continues executing. Paired with BAR.SYNC for deferred wait. |
| `BAR.SYNC` |  | __syncthreads() | default | |
| `BAR.SYNC.DEFER_BLOCKING` |  | __syncthreads() | default | |
| `DEPBAR.LE` |  | dependency barrier | default | |

### Bit Manipulation (25 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `BMSK` |  | mask generation | -G | |
| `BREV` | 17.51 cy (SFU) | __brev() | default | |
| `FLO.U32` |  | __clz()/__ffs() | default | |
| `FLO.U32.SH` |  | __clz()/__ffs() | default | |
| `LOP3.LUT` | 4.53 cy | __funnelshift / bitwise | default | |
| `PLOP3.LUT` |  |  | default | |
| `POPC` | ~7-8 cy (multi-cycle INT, corrected from 23.52) | __popc() | default | |
| `PRMT` | 4.52 cy | __byte_perm() | default | |
| `SGXT` |  | sign extend | default | |
| `SGXT.U32` |  | sign extend | default | |
| `SHF.L.U32` | 4.52 cy | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.L.U32.HI` | ~4.52 (similar) | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.L.U64.HI` |  | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.L.W.U32` | ~4.52 cy | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.L.W.U32.HI` | ~~4.52 (similar) | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.S32.HI` | 4.52 cy | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.S64` | ~4.52 cy | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.U32` | ~4.52 (similar) | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.U32.HI` | 4.52 cy | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.U64` |  | __funnelshift_l()/__funnelshift_r() | default | |
| `SHF.R.W.U32` |  | __funnelshift_l()/__funnelshift_r() | default | |
| `SHFL.BFLY` | 24.96 cy | __shfl_xor_sync() | default | |
| `SHFL.DOWN` | ~24.96 cy | __shfl_down_sync() | default | |
| `SHFL.IDX` | ~24.96 cy | __shfl_sync() | default | |
| `SHFL.UP` | ~24.96 cy | __shfl_up_sync() | default | |

### Cache Control (5 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `CCTL.E.PF1` |  | cache control | default | |
| `CCTL.E.PF2` |  | cache control | default | |
| `CCTL.IVALL` |  | cache control | default | |
| `QSPC.E.G` |  | query address space | -G | |
| `QSPC.E.S` |  | query address space | -G | |

### Control Flow (14 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `BMOV.32` |  |  | -G | |
| `BMOV.32.CLEAR` |  |  | -G | |
| `BRA` |  | if/else/loop branch | default | |
| `BRA.CONV` |  | if/else/loop branch | barrier probes | **Convergent branch** (compiler marks branches where all threads take same path) |
| `BRA.DIV` |  | if/else/loop branch | barrier probes | **Divergent branch** (compiler marks branches where threads may diverge) |
| `BRA.CONV` |  | if/else/loop branch | default | |
| `BRX` |  |  | default | |
| `BSSY` |  | compiler: divergence entry | default | |
| `BSYNC` |  | compiler: reconvergence | default | |
| `CALL.ABS.NOINC` |  | function call | -G | |
| `CALL.REL.NOINC` |  | function call | default | |
| `EXIT` | ~0 cy (thread termination) | return/kernel end | default | |
| `NOP` | 0 cy (pipeline filler) | pipeline filler | default | |
| `RET.ABS.NODEC` |  | function return | -G | |
| `RET.REL.NODEC` |  | function return | default | |
| `YIELD` | 2676.61 cy (=NANOSLEEP) | __nanosleep(0) | default | |

### Conversion (38 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `F2F.BF16.F32` |  |  | default | |
| `F2F.F16.F32` |  |  | default | |
| `F2F.F16.F32.RM` |  |  | default | |
| `F2F.F16.F32.RP` |  |  | default | |
| `F2F.F16.F32.RZ` |  |  | default | |
| `F2F.F32.F64` |  |  | default | |
| `F2F.F64.F32` |  |  | default | |
| `F2FP.BF16.F32.PACK_AB` | ~8.54 cy (BF16 round-trip) | format conversion | default | |
| `F2FP.F16.E4M3.UNPACK_B` | ~6 cy (FP8 decode) | format conversion | default | |
| `F2FP.F16.E5M2.UNPACK_B` | ~6 cy (FP8 E5M2 decode) | format conversion | default | |
| `F2FP.F16.F32.PACK_AB` | ~10.54 cy (FP16 round-trip) | format conversion | default | |
| `F2FP.F16.F32.PACK_AB.RZ` | ~~10.54 (similar) | format conversion | default | |
| `F2FP.SATFINITE.E4M3.F32.PACK_AB_MERGE_C` | ~18.54 cy (FP8 round-trip) | format conversion | default | |
| `F2FP.SATFINITE.E5M2.F32.PACK_AB_MERGE_C` | ~18.53 cy (FP8 E5M2 round-trip) | format conversion | default | |
| `F2I.CEIL.NTZ` |  | float-to-int cast | default | |
| `F2I.F64` |  | float-to-int cast | default | |
| `F2I.FLOOR.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.CEIL.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.FLOOR.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.TRUNC.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.U32.NTZ` |  | float-to-int cast | default | |
| `F2I.FTZ.U32.TRUNC.NTZ` |  | float-to-int cast | default | |
| `F2I.NTZ` |  | float-to-int cast | default | |
| `F2I.TRUNC.NTZ` | ~12.03 cy (F2I+I2F round-trip) | float-to-int cast | default | |
| `F2I.U32.NTZ` |  | float-to-int cast | default | |
| `F2I.U32.TRUNC.NTZ` |  | float-to-int cast | default | |
| `F2I.U64.TRUNC` |  | float-to-int cast | INT64 tiling probes | **Float to unsigned 64-bit with truncation.** New 64-bit conversion variant. |
| `I2F.F64` |  | int-to-float cast | default | |
| `I2F.F64.S64` |  | int-to-float cast | default | |
| `I2F.RM` |  | int-to-float cast | default | |
| `I2F.RP` |  | int-to-float cast | default | |
| `I2F.S16` | ~44.51 cy (INT16 I2F+F2I chain) | int-to-float cast | default | |
| `I2F.S8` | ~6 cy (direct byte-to-float) | int-to-float cast | --restrict | |
| `I2F.U16` |  | int-to-float cast | default | |
| `I2F.U32.RP` |  | int-to-float cast | default | |
| `I2F.U64.RP` |  | int-to-float cast | INT64 tiling probes | **Unsigned 64-bit to float with round-toward-positive.** New FP64 conversion variant. |
| `I2FP.F32.S32` | ~6 cy | int-to-float (packed) | default | |
| `I2FP.F32.S32.RZ` | ~~6 (similar) | int-to-float (packed) | default | |
| `I2FP.F32.U32` |  | int-to-float (packed) | default | |

### Data Movement (2 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `MOV` | ~2 cy (register move) | register assignment | default | |
| `SEL` | ~4.53 cy | ternary select | default | |

### FP16/BF16 Packed + Tensor Core Float (10 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `HADD2` | 4.54 cy | __hadd2() | default | |
| `HADD2.F32` | ~4.54 cy | __hadd2() | default | |
| `HFMA2` | 4.54 cy | __hfma2() | default | |
| `HFMA2.BF16_V2` | 4.01 cy (FASTEST FMA on Ada) | __hfma2(bfloat162) | default | |
| `HMMA.16816.F16` | 42.14 cy/WMMA (fastest float TC) | wmma::mma_sync() [tensor core] | default | |
| `HMMA.16816.F32` | 66.28 cy/WMMA (256 FMA) | wmma::mma_sync() [tensor core] | default | |
| `HMMA.16816.F32.BF16` | 66.33 cy/WMMA (=FP16->FP32) | wmma::mma_sync() [tensor core] | default | |
| `HMMA.1684.F32.TF32` | 66.66 cy/2xHMMA (TF32 via 2 instructions) | wmma::mma_sync() [tensor core] | default | |
| `HMNMX2` |  | __hmax2()/__hmin2() | default | |
| `HSETP2.GTU.AND` |  | __hgt2()/__hle2() | edge atomics probes | **Half2 packed comparison set-predicate** (greater-than-unordered, AND combiner). FP16 packed comparison -- first observation. |
| `HSETP2.LE.AND` |  | __hgt2()/__hle2() | -G debug + expanded probes | Half2 packed less-or-equal comparison. Second FP16 packed comparison variant. |
| `HMUL2` | ~4.54 cy (only with -fmad=false) | __hmul2() (-fmad=false) | -fmad=false | |

### FP32 Arithmetic (42 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `FADD` | 4.52 cy | a + b | default | |
| `FADD.FTZ` | ~4.52 cy | --use_fast_math: a + b | default | |
| `FADD.FTZ.RZ` | ~4.52 cy | --use_fast_math: a + b | default | |
| `FADD.RZ` | ~4.52 cy | a + b | default | |
| `FADD.SAT` | 4.52 cy (SAT=FREE) | __saturatef(a+b) | default | |
| `FCHK` |  | __isnanf()/__isinff() | default | |
| `FFMA` | 4.53 cy | fmaf(a,b,c) | default | |
| `FFMA.FTZ` | 4.51 cy (FTZ=FREE) | --use_fast_math: fmaf() | default | |
| `FFMA.RM` | ~4.53 cy | fmaf(a,b,c) | default | |
| `FFMA.RP` | ~4.53 cy | fmaf(a,b,c) | default | |
| `FFMA.RZ` | ~4.53 cy | fmaf(a,b,c) | default | |
| `FFMA.SAT` | ~4.53 (similar) | saturated FMA | default | |
| `FMNMX` |  | fminf()/fmaxf() | default | |
| `FMNMX.FTZ` |  | fminf()/fmaxf() | default | |
| `FMUL` | 4.52 cy | a * b | default | |
| `FMUL.D8` | ~4.52 (similar) | a * b | default | |
| `FMUL.FTZ` | ~4.52 (similar) | a * b | default | |
| `FMUL.FTZ.D8` | ~4.52 cy | a * b | default | |
| `FMUL.RZ` | ~4.52 (similar) | a * b | default | |
| `FMUL.SAT` | ~4.52 (similar) | a * b | default | |
| `FSEL` | 8.52 cy | ternary ? : | default | |
| `FSET.BF.GT.AND` |  |  | default | |
| `FSET.BF.GT.FTZ.AND` |  |  | default | |
| `FSETP.EQ.AND` |  | a > b (float comparison) | default | |
| `FSETP.EQ.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.EQ.OR` |  | a > b (float comparison) | default | |
| `FSETP.GE.AND` | ~8.52 cy | a > b (float comparison) | default | |
| `FSETP.GE.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.GEU.AND` |  | a > b (float comparison) | default | |
| `FSETP.GEU.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.GEU.OR` |  | a > b (float comparison) | default | |
| `FSETP.GT.AND` | ~8.52 cy | a > b (float comparison) | default | |
| `FSETP.GT.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.GTU.AND` |  | a > b (float comparison) | default | |
| `FSETP.GTU.FTZ.AND` | ~8.52 cy | a > b (float comparison) | default | |
| `FSETP.GTU.OR` |  | a > b (float comparison) | default | |
| `FSETP.LE.AND` |  | a > b (float comparison) | default | |
| `FSETP.LE.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.LT.AND` |  | a > b (float comparison) | default | |
| `FSETP.LT.FTZ.AND` |  | a > b (float comparison) | default | |
| `FSETP.NEU.AND` | ~8.52 cy | a > b (float comparison) | default | |
| `FSETP.NEU.FTZ.AND` |  | a > b (float comparison) | default | |

### FP64 Arithmetic (19 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `DADD` | 48.47 cy | double a + b | default | |
| `DFMA` | 54.48 cy | fma(double) | default | |
| `DFMA.RM` | ~54.48 (similar) | fma(double) | default | |
| `DFMA.RP` | ~54.48 (similar) | fma(double) | default | |
| `DMUL` | 48.47 cy | double a * b | default | |
| `DMUL.RP` | ~48.47 (similar) | double a * b | default | |
| `DSETP.EQ.AND` |  |  | default | |
| `DSETP.EQU.AND` |  |  | default | |
| `DSETP.GE.AND` |  |  | default | |
| `DSETP.GEU.AND` |  |  | default | |
| `DSETP.GT.AND` | ~38 cy |  | default | |
| `DSETP.GTU.AND` | ~38 cy |  | default | |
| `DSETP.LE.AND` |  |  | default | |
| `DSETP.LT.AND` |  |  | default | |
| `DSETP.MAX.AND` |  |  | default | |
| `DSETP.MIN.AND` |  |  | default | |
| `DSETP.NAN.AND` |  |  | default | |
| `DSETP.NE.AND` |  |  | default | |
| `DSETP.NEU.AND` |  |  | default | |

### Fence (5 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `MEMBAR.ALL.GPU` | 205.25 cy (__threadfence) | __threadfence() | default | |
| `MEMBAR.SC.CTA` |  | __threadfence_block() | default | |
| `MEMBAR.SC.GPU` |  |  | default | |
| `MEMBAR.SC.SYS` | 2583.37 cy (system-scope) | __threadfence_system() | default | |
| `MEMBAR.SC.VC` |  |  | -G | |

### Integer Arithmetic (24 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `IABS` | 0.26 cy/pair (sub-cycle modifier) | abs(int) | default | |
| `IADD3` | 2.52 cy | a + b (int32) | default | |
| `IADD3.X` | ~2.59 cy (carry propagation) | a + b (int32) | default | |
| `IDP.4A.S8.S8` | 4.53 cy (4x effective INT8) | __dp4a() [INT8 dot product] | default | |
| `IMAD` | 4.53 cy | a * b + c (int32) | default | |
| `IMAD.HI` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.HI.U32` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.IADD` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.MOV` | ~4.53 (similar) | a * b + c (int32) | default | |
| `IMAD.MOV.U32` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.SHL` | ~4.53 (similar) | a * b + c (int32) | default | |
| `IMAD.SHL.U32` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.U32` | ~4.53 (similar) | a * b + c (int32) | default | |
| `IMAD.WIDE` | 2.59 cy (INT64 ADD via carry chain) | a * b + c (int32) | default | |
| `IMAD.WIDE.U32` | ~4.53 cy | a * b + c (int32) | default | |
| `IMAD.WIDE.U32.X` | ~4.53 (similar) | a * b + c (int32) | default | |
| `IMAD.X` | ~4.53 cy | a * b + c (int32) | default | |
| `IMNMX` | ~4.53 cy | min(int)/max(int) | default | |
| `IMNMX.U32` | ~4.53 cy | min(int)/max(int) | default | |
| `LEA` |  |  | default | |
| `LEA.HI` |  |  | default | |
| `LEA.HI.SX32` |  |  | default | |
| `LEA.HI.X` |  |  | default | |
| `LEA.HI.X.SX32` |  |  | default | |

### Integer Comparison (29 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `ISETP.EQ.AND` | ~4.53 cy | a > b (int comparison) | default | |
| `ISETP.EQ.AND.EX` | ~~4.53 (similar) | a > b (int comparison) | default | |
| `ISETP.EQ.OR` |  | a > b (int comparison) | default | |
| `ISETP.EQ.U32.AND` |  | a > b (int comparison) | default | |
| `ISETP.EQ.U32.AND.EX` |  | a > b (int comparison) | default | |
| `ISETP.GE.AND` | ~4.53 cy | a > b (int comparison) | default | |
| `ISETP.GE.AND.EX` | ~~4.53 (similar) | a > b (int comparison) | default | |
| `ISETP.GE.OR` |  | a > b (int comparison) | default | |
| `ISETP.GE.U32.AND` |  | a > b (int comparison) | default | |
| `ISETP.GE.U32.OR` |  | a > b (int comparison) | tiling probes (-O3 --restrict) | Unsigned GE with OR predicate combiner |
| `ISETP.GE.U32.AND.EX` |  | a > b (int comparison) | default | |
| `ISETP.GT.AND` | ~4.53 cy | a > b (int comparison) | default | |
| `ISETP.GT.AND.EX` | ~~4.53 (similar) | a > b (int comparison) | default | |
| `ISETP.GT.U32.AND` |  | a > b (int comparison) | default | |
| `ISETP.GT.U32.AND.EX` |  | a > b (int comparison) | default | |
| `ISETP.GT.U32.OR` |  | a > b (int comparison) | default | |
| `ISETP.LE.AND` |  | a > b (int comparison) | default | |
| `ISETP.LE.U32.AND` |  | a > b (int comparison) | default | |
| `ISETP.LE.U32.AND.EX` |  | a > b (int comparison) | default | |
| `ISETP.LT.AND` | ~4.53 cy | a > b (int comparison) | default | |
| `ISETP.LT.AND.EX` | ~~4.53 (similar) | a > b (int comparison) | default | |
| `ISETP.LT.OR` |  | a > b (int comparison) | default | |
| `ISETP.LT.U32.AND` |  | a > b (int comparison) | default | |
| `ISETP.LT.U32.AND.EX` |  | a > b (int comparison) | default | |
| `ISETP.LT.U32.OR.EX` |  | a > b (int comparison) | default | |
| `ISETP.NE.AND` | ~4.53 cy | a > b (int comparison) | default | |
| `ISETP.NE.AND.EX` | ~~4.53 (similar) | a > b (int comparison) | default | |
| `ISETP.NE.OR` |  | a > b (int comparison) | default | |
| `ISETP.NE.U32.AND` |  | a > b (int comparison) | default | |

### Memory Constant (4 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `LDC` | 70.57 cy (constant cache chain) | constant memory (__constant__) | default | |
| `LDC.64` |  | constant memory (__constant__) | default | |
| `LDC.U16` |  | constant memory (__constant__) | -G debug + expanded probes | Unsigned 16-bit constant memory load (sub-word constant cache) |
| `ULDC` |  |  | default | |
| `ULDC.64` |  |  | default | |

### Memory Global (47 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `LD.E` |  |  | default | |
| `LD.E.128` |  |  | default | |
| `LD.E.64` |  |  | default | |
| `LD.E.64.STRONG.SYS` |  |  | default | |
| `LD.E.STRONG.GPU` |  |  | default | |
| `LD.E.STRONG.SYS` |  |  | default | |
| `LD.E.U16` |  |  | default | |
| `LD.E.U16.STRONG.SYS` |  |  | default | |
| `LD.E.U8` |  |  | default | |
| `LDG.E` | 92-123 cy (L2 hit, varies by SKU) | global load (default) | default | |
| `LDG.E.128` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.128.CONSTANT` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.64` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.64.CONSTANT` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.64.STRONG.SYS` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.CONSTANT` | ~33 cy (L1 read-only cache) | __ldg() | default | |
| `LDG.E.S16` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.S8` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.STRONG.SYS` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.U16` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.U16.CONSTANT` | ~92-123 (similar) | global load (default) | --restrict | |
| `LDG.E.U16.STRONG.SYS` | ~92-123 (similar) | global load (default) | default | |
| `LDG.E.U8` | ~44.99 cy (byte pointer chase) | global load (default) | default | |
| `LDG.E.U8.CONSTANT` | ~92-123 (similar) | global load (default) | --restrict | |
| `LDGDEPBAR` | ~0 cy (barrier token, not execution) | __pipeline_commit() | default | |
| `LDGSTS.E` | 363.28 cy/iter (async copy with sync) | cp.async / __pipeline_memcpy_async() | default | |
| `LDGSTS.E.64.ZFILL` | ~363.28 (similar) | cp.async / __pipeline_memcpy_async() | -G | |
| `LDGSTS.E.BYPASS.128` | ~363.28 (similar) | cp.async / __pipeline_memcpy_async() | default | |
| `LDGSTS.E.BYPASS.128.ZFILL` | ~363.28 (similar) | cp.async / __pipeline_memcpy_async() | -G | |
| `LDGSTS.E.ZFILL` | ~363.28 (similar) | cp.async / __pipeline_memcpy_async() | -G | |
| `ST.E` |  |  | default | |
| `ST.E.128` |  |  | default | |
| `ST.E.64` |  |  | default | |
| `ST.E.64.STRONG.SYS` |  |  | default | |
| `ST.E.STRONG.SYS` |  |  | default | |
| `ST.E.U16` |  |  | default | |
| `ST.E.U16.STRONG.SYS` |  |  | default | |
| `ST.E.U8` |  |  | default | |
| `STG.E` | ~~4 (similar) | global store | default | |
| `STG.E.128` |  | global store | default | |
| `STG.E.64` |  | global store | default | |
| `STG.E.64.STRONG.SYS` |  | global store | default | |
| `STG.E.EF` | ~4 cy issue (evict-first, async) | __stcs() (evict-first) | default | |
| `STG.E.STRONG.SYS` |  | global store | default | |
| `STG.E.U16` |  | global store | default | |
| `STG.E.U16.STRONG.SYS` |  | global store | default | |
| `STG.E.U8` |  | global store | default | |

### Memory Local (Spill) (5 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `LDL` |  | local memory load (spill) | -G | |
| `LDL.64` |  | local memory load (spill) | default | |
| `LDL.LU` |  | local memory load (spill) | --restrict | |
| `STL` |  | local memory store (spill) | --restrict / -G | |
| `STL.64` |  | local memory store (spill) | default | |

### Memory Shared (9 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `LDS` | 28.03 cy (shared memory) | shared memory load | default | |
| `LDS.128` |  | shared memory load | default | |
| `LDS.64` |  | shared memory load | default | |
| `LDS.S8` |  | shared memory load | INT8 tiling probes | **Signed 8-bit shared memory load.** Sign-extends byte to 32-bit register. First sub-byte signed smem load observed. |
| `LDS.S16` |  | shared memory load | INT16 tiling probes | **Signed 16-bit shared memory load.** Sign-extends short to 32-bit register. |
| `LDS.U8` |  | shared memory load | bitops tiling probes | Unsigned 8-bit shared memory load. |
| `LDS.U16` |  | shared memory load | edge atomics probes | Unsigned 16-bit shared memory load. |
| `STS` |  | shared memory store | default | |
| `STS.64` |  | shared memory store | -O3 no-restrict | 64-bit shared memory store (without --restrict) |
| `STS.U16` |  | shared memory store | default | |

### Other (6 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `BPT.TRAP` |  |  | default | |
| `ERRBAR` |  |  | default | |
| `FRND` |  |  | default | |
| `FRND.FLOOR` |  |  | default | |
| `FRND.TRUNC` |  |  | default | |
| `NANOSLEEP` |  | __nanosleep() | default | |

### SFU (MUFU) (9 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `MUFU.COS` | ~23.50 cy | __cosf() | default | |
| `MUFU.EX2` | 17.55 cy | __expf() / __exp2f() | default | |
| `MUFU.LG2` | 39.53 cy | __logf() / __log2f() | default | |
| `MUFU.RCP` | 41.53 cy | __frcp_rn() / 1.0f/x | default | |
| `MUFU.RCP64H` | 17.54 cy | __frcp_rn() / 1.0f/x | default | |
| `MUFU.RSQ` | 39.53 cy | rsqrtf() | default | |
| `MUFU.RSQ64H` | ~17.54 cy (FP64 rsqrt approx) | 1.0/sqrt(double) [approx] | default | |
| `MUFU.SIN` | 23.50 cy | __sinf() | default | |
| `MUFU.SQRT` | ~17.5 cy (only with --use_fast_math) | sqrtf() [--use_fast_math] | --use_fast_math | |

### Special Register (7 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `CS2R` |  |  | default | |
| `CS2R.32` |  |  | default | |
| `P2R` |  | predicate spill to register | --use_fast_math | |
| `R2P` |  | predicate reload | default | |
| `R2UR` |  |  | -G | |
| `S2R` |  | threadIdx/blockIdx/clock | default | |
| `S2UR` |  |  | default | |

### Tensor Core Integer + Data (8 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `IMMA.16816.S8.S8` | 34.06 cy/WMMA (INT8, 2x faster than float) | wmma::mma_sync() [INT TC] | default | |
| `IMMA.16816.S8.S8.SAT` | ~34.06 (similar) | wmma::mma_sync() [INT TC] | -G | |
| `IMMA.8832.S4.S4` | 28.05 cy/WMMA (INT4, fastest TC) | wmma::mma_sync() [INT TC] | default | |
| `IMMA.8832.S4.S4.SAT` | ~28.05 (similar) | wmma::mma_sync() [INT TC] | -G | |
| `IMMA.8832.U4.U4` | 28.05 cy/WMMA (=INT4 S4) | wmma::mma_sync() [INT TC] | default | |
| `IMMA.8832.U4.U4.SAT` | ~28.05 (similar) | wmma::mma_sync() [INT TC] | -G | |
| `LDSM.16.M88.4` | ~28 cy (shared memory matrix load) | wmma::load_matrix_sync() [from smem] | default | |
| `MOVM.16.MT88` |  | register assignment | -G | |

### Texture/Surface (11 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `SULD.D.BA.1D.STRONG.SM` |  | surface load | default | |
| `SULD.D.BA.1D.STRONG.SM.IGN` |  | surface load | default | |
| `SULD.D.BA.1D.STRONG.SM.TRAP` |  | surface load | default | |
| `SUST.D.BA.1D.STRONG.SM` |  | surface store | default | |
| `SUST.D.BA.1D.STRONG.SM.IGN` |  | surface store | default | |
| `SUST.D.BA.1D.STRONG.SM.TRAP` |  | surface store | default | |
| `TEX.B.LL` |  | tex1D/2D/3D fetch | default | |
| `TEX.SCR.B.LL` |  | tex1D/2D/3D fetch | default | |
| `TEX.SCR.LL` |  | tex1D/2D/3D fetch | default | |
| `TLD.SCR.B.LZ` |  | texture load | default | |
| `TLD.SCR.LZ` |  | texture load | default | |

### Uniform Datapath (12 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `UFLO.U32` |  |  | default | |
| `UIADD3` |  |  | default | |
| `UIADD3.X` |  |  | default | |
| `UIMAD` |  |  | default | |
| `UIMAD.WIDE` |  |  | tiling probes (-O3 --restrict) | **Uniform IMAD with 64-bit result** (for uniform 64-bit address computation) |
| `UIMAD.WIDE.U32` |  |  | default | |
| `UISETP.GE.AND` |  |  | INT tiling probes | Uniform unsigned greater-or-equal with AND combiner |
| `UISETP.GE.U32.AND` |  |  | --maxrregcount | |
| `UISETP.GT.AND` |  |  | --maxrregcount | |
| `UISETP.NE.U32.AND` |  |  | barrier probes | Uniform unsigned not-equal set-predicate |
| `USEL` |  |  | barrier probes | **Uniform conditional select** (uniform datapath equivalent of SEL) |
| `ULOP3.LUT` |  |  | default | |
| `UMOV` |  |  | default | |
| `UPOPC` |  |  | default | |
| `USHF.L.U32` |  |  | default | |
| `UPRMT` |  |  | INT8 tiling probes | **Uniform byte permute.** Uniform datapath equivalent of PRMT. Used for warp-uniform byte shuffle in INT8 pack/unpack patterns. |
| `USHF.R.S32.HI` |  |  | default | |
| `USHF.R.U32.HI` |  |  | bitops tiling probes | Uniform unsigned right shift high |
| `ULEA` | ~2.5 cy (uniform pipeline) |  | tiling probes (-O3 --restrict) | Uniform load effective address for tile base computation. Opcode 0x7891. |

### Warp Vote/Match/Redux (7 mnemonics)

| Mnemonic | Measured Latency | CUDA/PTX Intrinsic | Flags | Notes |
|---|---|---|---|---|
| `MATCH.ALL` | ~25 cy | __match_all_sync() | default | |
| `MATCH.ANY` |  | __match_any_sync() | default | |
| `VOTE.ALL` |  | __all_sync() | default | |
| `VOTE.ANY` |  | __any_sync()/__ballot_sync() | default | |
| `VOTEU.ANY` |  |  | default | |
| `WARPSYNC` |  | __syncwarp() | default | |
| `WARPSYNC.EXCLUSIVE` |  | __syncwarp() | -G | |

---

**Total: 443 unique SASS mnemonics across 25 categories.**

All latencies measured on RTX 4070 Ti (SM 8.9, 2625 MHz, 60 SMs).
See `RESULTS.md` for measurement methodology, ncu cross-validation,
and corrected values.