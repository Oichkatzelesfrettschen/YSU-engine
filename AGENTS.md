# YSU-Engine -- Agent and Developer Reference

## Overview

YSU-Engine is a multi-subsystem rendering and physics engine with:
- CPU raytracer with BVH, denoising, NeRF inference, and upscaling
- Vulkan GPU rendering pipeline
- CUDA D3Q19 Lattice Boltzmann Method (LBM) fluid simulation kernels
- SASS reverse engineering toolkit for Ada Lovelace
- GPU box-counting fractal dimension analysis
- Sparse brick-map LBM for high-sparsity domains

## CUDA LBM Reference Architecture

The primary GPU physics subsystem. 24 production CUDA kernels spanning 10
precision tiers with two memory layouts (AoS, i-major SoA).

| Document | Purpose |
|----------|---------|
| `src/cuda_lbm/README.md` | Kernel index, measured performance tables, layout details |
| `docs/sass/SM89_ARCHITECTURE_REFERENCE.md` | Hardware specs, roofline model, L2 regime analysis |
| `docs/sass/NVIDIA_SASS_ADA_LOVELACE_REFERENCE.md` | Full SASS ISA reference for SM 8.9 |
| `src/cuda_lbm/include/lbm_kernels.h` | Kernel variant enum and registry |
| `src/cuda_lbm/include/lbm_metrics.h` | Benchmark result structs and GPU specs |

### Key Performance Facts

- All scalar LBM kernels (FP32 and below) are **bandwidth-bound** on Ada
- INT8 SoA is Pareto-optimal: 5643 MLUPS, 76 MB VRAM, 2.85x FP32
- SoA layout beats AoS by 1.81x-2.22x at 128^3 (scatter penalty elimination)
- FP64/DD kernels are compute-bound (64:1 FP64 ratio on Ada gaming SKUs)
- Canonical benchmark grid: 128^3 (GDDR6X-bound regime)

## SASS RE Toolkit

First-party SASS reverse engineering for Ada Lovelace.

| Document | Purpose |
|----------|---------|
| `src/sass_re/RESULTS.md` | Measured instruction latencies and throughput |
| `src/sass_re/microbench/` | Latency and throughput probe kernels |
| `src/sass_re/probes/` | 9 SASS probe kernel files (3107 instructions analyzed) |

Key measurements: FFMA 4.54 cyc, IADD3 2.51 cyc, MUFU.RCP 41.55 cyc,
LDG 92.29 cyc, LDS 28.03 cyc.

## Build and Benchmark

### Building CUDA Targets

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

CUDA is auto-detected via `find_package(CUDAToolkit)`. If found, the
`src/cuda_lbm/` subdirectory is included. Target architectures: SM 89 (Ada)
and SM 80 (Ampere fallback).

### Running Benchmarks

```sh
# Full benchmark suite
build/bin/lbm_bench --all --grid 128 --output table

# Single kernel
build/bin/lbm_bench --kernel int8_soa --grid 64,128,256

# Physics validation only
build/bin/lbm_bench --validate

# Performance regression check
build/bin/lbm_bench --regression

# Occupancy report
build/bin/lbm_bench --occupancy
```

### Running Tests

```sh
build/bin/lbm_test
```

Runs conservation tests, performance regression tests, and MRT stability
validation for all physics-valid kernels.

## Profiling Workflow

### Nsight Compute (single kernel)

```sh
src/cuda_lbm/scripts/profile_ncu.sh <kernel_name> <grid_size> [output_dir]
```

Collects full .ncu-rep with `--launch-skip 5 --launch-count 3` (warmed up).
Secondary pass extracts key metrics to CSV: DRAM/L2/L1 throughput, occupancy,
stall reasons, cache hit rates, register count.

### Nsight Compute (batch)

```sh
src/cuda_lbm/scripts/profile_ncu_all.sh
```

Profiles all physics-valid SoA kernels at 128^3.

### Nsight Systems (timeline)

```sh
src/cuda_lbm/scripts/profile_nsys.sh
```

Full timeline with CUDA + NVTX + OS runtime traces.

### Register Spill Check

```sh
src/cuda_lbm/scripts/check_spills.sh
```

Parses ptxas output for register spills and LMEM usage. Exits nonzero if any
production kernel has LMEM > 0 bytes.

## Performance Baselines

All baselines measured on RTX 4070 Ti Super (AD103, 66 SMs, 504 GB/s peak).
See `src/cuda_lbm/README.md` for full tables.

Top 5 physics-valid at 128^3 (GDDR6X-bound):

| Rank | Tier | MLUPS | BW% | VRAM |
|------|------|-------|-----|------|
| 1 | INT8 SoA | 5643 | 51.5% | 76 MB |
| 2 | FP8 e4m3 SoA | 5408 | 49.4% | 76 MB |
| 3 | FP8 e5m2 SoA | 5280 | 48.2% | 76 MB |
| 4 | FP16 SoA H2 | 3802 | 69.4% | 152 MB |
| 5 | INT16 SoA | 3569 | 65.1% | 152 MB |

## SM89 Optimization Checklist

When modifying or adding CUDA LBM kernels:

1. [ ] Use i-major SoA layout with pull-scheme (not AoS push-scheme)
2. [ ] Verify coalesced memory access for all 19 directions
3. [ ] Check register count with `-Xptxas -v`; target <= 128 regs/thread
4. [ ] Run `check_spills.sh` -- zero LMEM for production kernels
5. [ ] Use `__launch_bounds__(128, 4)` for standard kernels
6. [ ] Use `__ldg()` for read-only input arrays
7. [ ] Promote to FP32 before compute (storage-compute split pattern)
8. [ ] Benchmark at 128^3 for GDDR6X-bound baselines
9. [ ] Tag benchmark results with bandwidth regime (L2-bound vs GDDR6X-bound)
10. [ ] Verify physics: mass conservation, momentum conservation, density stability
11. [ ] FP8 kernels: guard with `#if __CUDA_ARCH__ >= 890`
12. [ ] MRT kernels: verify ghost moment damping (s_ghost=1.0)
