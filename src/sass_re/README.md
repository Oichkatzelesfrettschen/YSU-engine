# SASS Reverse Engineering Toolkit

Hands-on tools for reverse-engineering NVIDIA SASS across multiple GPU architectures.
Currently supports **Ada Lovelace (SM 8.9, RTX 4070 Ti Super)** and
**Pascal (SM 6.1, GTX 1050 Ti)**. Real measurements, real disassembly, real encoding analysis.

See [RESULTS.md](RESULTS.md) for measured data and [PAPER_OUTLINE.md](PAPER_OUTLINE.md) for our comparison paper.

## Directory layout

```
src/sass_re/
  probes/           -- minimal CUDA kernels that isolate specific instructions
  microbench/       -- latency & throughput measurement harnesses
  scripts/          -- automation: compile, disassemble, compare, analyze, profile
  results/          -- output from runs (GPU-tagged subdirectories)
  RESULTS.md        -- Ada Lovelace measurements and analysis
  PAPER_OUTLINE.md  -- research paper outline (Pascal vs Ada comparison)
  COMPARISON.md     -- auto-generated cross-architecture analysis
```

## Quick start

```bash
cd src/sass_re

# Disassemble all 17 probes (original 9 + 8 expanded) for Ada SM 8.9
sh scripts/disassemble_expanded.sh results/ada_expanded

# Profile with Nsight Compute (requires live GPU + root/admin for HW counters)
sh scripts/profile_ncu_probes.sh results/ncu_ada

# Profile timeline with Nsight Systems
sh scripts/profile_nsys_timeline.sh ./my_benchmark --grid 128
```

PowerShell scripts also available for Windows:
```powershell
.\scripts\disassemble_all.ps1 -Arch sm_89 -GpuTag Ada_RTX4070TiS
.\scripts\build_and_run_latency.ps1 -Arch sm_89
.\scripts\build_and_run_throughput.ps1 -Arch sm_89
python scripts/encoding_analysis.py results/<gpu_tag_timestamp>/
```

## Requirements

- **CUDA Toolkit 13.x** -- for SM 7.5+ (Turing, Ampere, Ada, Hopper)
- **CUDA Toolkit 12.x** -- required for SM 6.1 Pascal (CUDA 13.x dropped SM < 7.5)
- **Nsight Compute (ncu)** -- for hardware counter validation
- **Nsight Systems (nsys)** -- for timeline profiling
- **Python 3.x** -- for comparison and encoding analysis
- Scripts auto-detect the correct CUDA version based on target SM

## Probe Coverage Matrix

### Original probes (9 kernels)

| Kernel file | Isolated instructions | SM 6.1 compat |
|---|---|---|
| probe_fp32_arith.cu | FADD, FMUL, FFMA, FMNMX | Yes |
| probe_int_arith.cu | IADD3/IADD, IMAD/XMAD, ISETP, LEA | Yes |
| probe_mufu.cu | MUFU (sin, cos, rsqrt, rcp, ex2, lg2) | Yes |
| probe_bitwise.cu | LOP3/LOP, SHF, PRMT, BFI, FLO, POPC | Yes |
| probe_memory.cu | LDG, STG, LDS, STS, atomics, MEMBAR | Yes |
| probe_conversions.cu | F2I, I2F, F2F, FRND | Yes |
| probe_control_flow.cu | BRA, divergence, SHFL, VOTE, predication | Yes |
| probe_special_regs.cu | S2R (tid, ctaid, clock, globaltimer) | Yes |
| probe_tensor.cu | HMMA (FP16->FP32) via WMMA | No (SM 7.0+) |

### Expanded probes (8 new kernels)

| Kernel file | Isolated instructions | SM requirement | Source pattern |
|---|---|---|---|
| probe_fp16_half2.cu | HADD2, HMUL2, HFMA2, HMNMX2, H2F/F2H | SM 7.0+ | kernels_fp16_soa_half2.cu |
| probe_fp8_precision.cu | F2FP.E4M3, F2FP.E5M2, uchar4 vectorized load | SM 8.9+ | kernels_fp8.cu, kernels_fp8_soa.cu |
| probe_int8_dp4a.cu | IDP.4A.S8.S8 (dp4a dot product) | SM 6.1+ | kernels_int8.cu |
| probe_tensor_extended.cu | HMMA.1684.TF32, HMMA.BF16, IMMA.S8, IMMA.S4 | SM 8.0+ | kernels_tensor_core.cu |
| probe_cache_policy.cu | STG.E.EF (streaming store), LDG.E.CONSTANT | SM 8.0+ | kernels_fp32_soa_cs.cu |
| probe_nibble_packing.cu | SHF/BFI/LOP3 nibble chains, PRMT permute | SM 6.1+ | kernels_int4.cu, kernels_fp4.cu |
| probe_warp_reduction.cu | SHFL.DOWN/BFLY/IDX, VOTE, MATCH.ALL, REDUX.SUM/MIN/MAX | SM 7.0+ | kernels_box_counting.cu |
| probe_bf16_arithmetic.cu | HFMA2.BF16_V2, F2FP.BF16, BF16 decode chain | SM 8.0+ | kernels_bf16.cu |

### New instruction coverage (32 SASS mnemonics added)

```
CS2R                            HMMA.16816.F32.BF16            ISETP.EQ.AND
F2FP.BF16.F32.PACK_AB          HMMA.1684.F32.TF32             ISETP.GT.U32.OR
F2FP.F16.E4M3.UNPACK_B         HMNMX2                         LD.E / LD.E.64
F2FP.F16.E5M2.UNPACK_B         IADD3.X                        LDG.E.S8
F2FP.SATFINITE.E4M3.*          IDP.4A.S8.S8                   MATCH.ALL
F2FP.SATFINITE.E5M2.*          IMMA.16816.S8.S8               REDUX.SUM / REDUX.SUM.S32
FCHK                            IMMA.8832.S4.S4                ST.E.64
FFMA.RZ                         IMNMX                          STG.E.EF / STG.E.U8
HADD2 / HFMA2                                                  VOTE.ALL / VOTE.ANY
```

## Profiling Scripts

| Script | Tool | Purpose |
|---|---|---|
| `disassemble_expanded.sh` | nvcc + cuobjdump | Compile and disassemble all 17 probes |
| `profile_ncu_probes.sh` | ncu (Nsight Compute) | Hardware counter validation (instruction mix, occupancy, memory BW) |
| `profile_nsys_timeline.sh` | nsys (Nsight Systems) | Timeline profiling for kernel launches and memory transfers |
| `disassemble_all.ps1` | nvcc + cuobjdump | Windows: compile and disassemble original 9 probes |
| `build_and_run_latency.ps1` | nvcc | Windows: run latency microbenchmark |
| `build_and_run_throughput.ps1` | nvcc | Windows: run throughput microbenchmark |
| `encoding_analysis.py` | Python | Parse SASS, extract opcode/control word bit fields |
| `compare_architectures.py` | Python | Cross-GPU ISA delta analysis |

## Supported GPUs

| GPU | Architecture | SM | Status |
|---|---|---|---|
| RTX 4070 Ti Super | Ada Lovelace | 8.9 | Measured (17 probes validated) |
| RTX 4070 Ti | Ada Lovelace | 8.9 | Measured (17 probes validated) |
| GTX 1050 Ti | Pascal | 6.1 | Ready (awaiting hardware) |

Any CUDA-capable GPU can be tested by passing the appropriate `-Arch sm_XX` parameter.
