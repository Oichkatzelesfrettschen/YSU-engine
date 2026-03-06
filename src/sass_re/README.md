# SASS Reverse Engineering Toolkit

Hands-on tools for reverse-engineering NVIDIA SASS (SM 8.9 / Ada Lovelace)
on an RTX 4070 Ti Super. Real measurements, real disassembly, real encoding analysis.

See [RESULTS.md](RESULTS.md) for measured latencies, throughputs, and encoding findings.

## Directory layout

```
src/sass_re/
  probes/           -- minimal CUDA kernels that isolate specific instructions
  microbench/       -- latency & throughput measurement harnesses
  scripts/          -- automation: compile, disassemble, parse, diff
  results/          -- output from disassembly runs and benchmarks
  RESULTS.md        -- collected measurements and analysis
```

## Quick start

```powershell
# From repo root:
cd src/sass_re

# 1. Compile all probe kernels and dump SASS:
powershell -ExecutionPolicy Bypass -File scripts/disassemble_all.ps1

# 2. Run latency microbenchmark:
powershell -ExecutionPolicy Bypass -File scripts/build_and_run_latency.ps1

# 3. Run throughput microbenchmark:
powershell -ExecutionPolicy Bypass -File scripts/build_and_run_throughput.ps1

# 4. Analyze binary encodings from disassembly:
python scripts/encoding_analysis.py results/<timestamp_dir>/
```

## Requirements

- CUDA Toolkit 13.x (nvcc, cuobjdump, nvdisasm)
- MSVC Build Tools (vcvars64.bat)
- Python 3.x (for encoding analysis)
- `-allow-unsupported-compiler` flag if using VS 2025 with CUDA 13.1

## What each probe does

| Kernel file | Isolated instructions |
|---|---|
| probe_fp32_arith.cu | FADD, FMUL, FFMA, FMNMX |
| probe_int_arith.cu | IADD3, IMAD, ISETP, LEA |
| probe_mufu.cu | MUFU (sin, cos, rsqrt, rcp, ex2, lg2) |
| probe_bitwise.cu | LOP3, SHF, PRMT, BFI, FLO, POPC |
| probe_memory.cu | LDG, STG, LDS, STS, LDGSTS, atomics |
| probe_conversions.cu | F2I, I2F, F2F, FRND |
| probe_control_flow.cu | BRA, BSSY, BSYNC, WARPSYNC, EXIT |
| probe_special_regs.cu | S2R (tid, ctaid, clock, globaltimer) |
| probe_tensor.cu | HMMA (tensor core) via wmma intrinsics |

## Requirements

- CUDA Toolkit (you have v13.1)
- Python 3.x (for encoding analysis)
- Nsight Compute (for profiling -- you have 2025.4.1)
