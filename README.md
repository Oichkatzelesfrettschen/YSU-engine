# YSU Engine

A C11 rendering and physics engine with an integrated SASS reverse engineering
toolkit. The engine provides CPU and GPU rendering pipelines, fluid simulation
via D3Q19 Lattice Boltzmann kernels, and nuclear/quantum physics modules. The
SASS toolkit empirically measures NVIDIA GPU instruction latencies and
throughput at the machine-code level, feeding directly into hand-optimized
inline PTX kernels.

### Start here

| If you want to... | Read this |
|---|---|
| Understand the SASS measurements | [`src/sass_re/RESULTS.md`](src/sass_re/RESULTS.md) |
| Learn to read GPU assembly from scratch | [`LEARNING_GUIDE.md`](src/sass_re/instant_ngp/docs/LEARNING_GUIDE.md) |
| See the optimized kernels + SASS diffs | [`src/sass_re/instant_ngp/`](src/sass_re/instant_ngp/) |
| Reproduce the 3.16x benchmark | [`src/sass_re/instant_ngp/README.md`](src/sass_re/instant_ngp/README.md) |
| Browse the full engine | [`src/`](src/) -- start with [`render/render.c`](src/render/render.c) |

---

## SASS Reverse Engineering Toolkit

Empirical measurements from an RTX 4070 Ti Super (Ada Lovelace, SM 8.9).

| Instruction | Latency | Throughput (ops/clk/SM) |
|---|---|---|
| FFMA (fused multiply-add) | 4.54 cyc | 44.6 |
| IADD3 (3-input integer add) | 2.51 cyc | 68.2 |
| MUFU.EX2 (fast exp, SFU) | 17.56 cyc | 9.9 |
| MUFU.RCP (reciprocal, SFU) | 41.55 cyc | -- |
| LDG (global memory chase) | 92.29 cyc | -- |
| LDS (shared memory chase) | 28.03 cyc | -- |
| SHFL.BFLY (warp shuffle) | 24.96 cyc | -- |

**Toolkit:** 9 probe kernels (FP32, integer, MUFU, bitwise, memory, conversions, control flow, special regs, tensor cores) + latency/throughput microbenchmarks with 512-deep dependent chains. Multi-architecture pipeline with parameterized scripts -- Pascal (SM 6.1) vs Ada (SM 8.9) comparison ready.

**Encoding analysis:** The 64-bit SASS instruction word was reverse-engineered by diffing same-opcode instructions with different operands. Mapped register fields for FADD, FFMA, IADD3, LOP3, MOV, LDG, STG. Opcode lives in the low 16 bits (e.g. FADD = 0x7221, IADD3 = 0x7210, LDG = 0x7981).

Full results: [`src/sass_re/RESULTS.md`](src/sass_re/RESULTS.md)

## Instant-NGP Inline PTX Kernels

Three Instant-NGP kernels rewritten in inline PTX to produce optimal SASS,
with every instruction hand-chosen and verified by disassembly.

| Kernel | Speedup vs nvcc -O2 | Key technique |
|---|---|---|
| MLP Forward (27->64->64->4) | 3.16x | 8-wide ILP FFMA chains, shared mem weight tiling, FMNMX ReLU, MUFU sigmoid |
| Volume Rendering | 1.53x | MUFU.EX2 fast exp, predicated early exit, warp SHFL neighbor sharing |
| Hash Grid Encoding | 1.11x | float2 vectorized LDG.E.64, SW pipelining across levels, LOP3 XOR |

The MLP kernel is compute-bound (6,249 FFMA instructions). The compiler
generates sequential accumulator chains without exploiting the 8 independent
dot-product lanes available for overlap. The hand-written version keeps 8 FFMA
accumulators in flight simultaneously, saturating the FP32 pipeline. Shared
memory weight tiling eliminates redundant global loads. FMNMX replaces a
branch-based ReLU.

The reference kernels are plain CUDA compiled with `nvcc -arch=sm_89 -O2`.
Source code, PTX, and SASS diffs are in [`src/sass_re/instant_ngp/`](src/sass_re/instant_ngp/).

### Reproduce

```powershell
cd src/sass_re/instant_ngp
powershell -ExecutionPolicy Bypass -File build_and_verify.ps1
```

Requires CUDA 13.x and an SM 7.5+ GPU. Tested on RTX 4070 Ti Super.

### Documentation

- [Explained for Everyone](src/sass_re/instant_ngp/docs/EXPLAINED_FOR_EVERYONE.md) -- no CS background needed
- [Learning Guide](src/sass_re/instant_ngp/docs/LEARNING_GUIDE.md) -- teaches SASS reading from scratch
- [Technical Reference](src/sass_re/instant_ngp/docs/TECHNICAL_REFERENCE.md) -- register counts, SASS diffs, architecture details

---

## Engine Components

### Path Tracer
- Tile-based multithreaded renderer -- persistent thread pool, 64-byte-aligned per-thread state, atomic job stealing
- Adaptive sampling via Welford online variance -- each pixel converges independently, saves 40-70% of samples on smooth regions
- Deterministic per-pixel RNG (xorshift32 + Fibonacci hash + Murmur finalizer) -- same image regardless of thread count
- Materials: Lambertian, Metal (fuzz), Dielectric (Snell + Schlick + TIR), Emissive (HDR)
- Beer-Lambert fog, Russian roulette, 4 debug viz modes

### BVH
- Arena-allocated contiguous DFS-order nodes, near-first child traversal with early-out
- ML policy pruning (experimental) -- offline-trained prune decisions applied via binary search, with per-node visit telemetry

### NeRF on CPU
- AVX2/AVX-512 vectorized MLP inference (27->64->64->4) with runtime CPUID detection and scalar fallback
- 12-level hash grid encoding with software prefetch, 64^3 occupancy grid for empty-space skipping
- Batched 8-ray variant, fp16 weights on disk with hand-written half-to-float expansion

### Vulkan GPU Compute
- Interactive raytracer with WASD + mouse-look camera, progressive accumulation
- GPU LBVH construction, hybrid mesh + NeRF rendering (28 modes), depth prepass at quarter resolution
- 6 GLSL compute shaders: raytracer, quantum wavefunction, quantum raymarch, nuclear density, thermal diffusion, tonemap

### Nuclear & Quantum Physics
- **RBMK-1000 reactor sim** -- Chernobyl Unit 4 at 3200 MWt, 1661 fuel channels, 6 materials with IAEA correlations, 3D heat diffusion + 1D coolant flow with boiling transitions, Zircaloy oxidation with positive void coefficient feedback
- **Quantum orbital raymarcher** -- two-pass Vulkan compute for hydrogen-like atoms up to Z~30, Aufbau electron filling, Slater Z_eff, signed wavefunction phase coloring

### Mesh Editor
- Single-file immediate-mode 3D editor on raylib -- Grab, Rotate, Scale, Extrude, Inset, Bevel with axis constraints
- Vertex/Edge/Face selection via Moller-Trumbore ray picking, OBJ import/export

### Denoiser
- Separable bilateral filter with cache-optimized vertical strips, Rec.709 luminance range kernel
- ONNX runtime and GPU shader paths for ML denoising

---

## Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

CMake auto-detects Vulkan, raylib, OpenMP, AVX2. Missing deps skip those targets -- the core path tracer needs only pthreads.

## Run

```bash
# Quick render
YSU_W=320 YSU_H=180 YSU_SPP=4 ./build/bin/ysu

# Full quality
YSU_W=1920 YSU_H=1080 YSU_SPP=128 YSU_ADAPTIVE=1 YSU_NEURAL_DENOISE=1 ./build/bin/ysu
```

Windows:
```powershell
$env:YSU_W=1920; $env:YSU_H=1080; $env:YSU_SPP=128; .\build\bin\ysu.exe
```

## Configuration

Environment variables only -- no config files, no arg parsing:

| Variable | Default | Description |
|---|---|---|
| `YSU_W` / `YSU_H` | 800 / 600 | Image dimensions |
| `YSU_SPP` | 64 | Samples per pixel |
| `YSU_DEPTH` | 10 | Max bounce depth |
| `YSU_THREADS` | auto | Thread count (0 = all cores) |
| `YSU_TILE` | 32 | Tile size for MT renderer |
| `YSU_ADAPTIVE` | 0 | Adaptive sampling (Welford variance) |
| `YSU_SPP_MIN` | 16 | Min SPP before adaptive early-stop |
| `YSU_REL_ERR` / `YSU_ABS_ERR` | 0.01 / 0.005 | Convergence thresholds |
| `YSU_NEURAL_DENOISE` | 0 | Enable denoiser |
| `YSU_FOG` | 0 | Beer-Lambert fog |

## Project Structure

```
src/
  core/        -- vec2-4, ray, camera, sphere, triangle, image, material, color
  render/      -- CPU renderer, BVH, scene loader, G-buffer, postprocess
  denoise/     -- bilateral, neural, ONNX denoiser
  nerf/        -- NeRF SIMD inference, hash grid, batch scheduler
  vulkan/      -- Vulkan compute pipelines, LBVH, GPU BVH, OBJ loader
  physics/     -- quantum volume, nuclear fission/fusion, reactor thermal
  editor/      -- mesh editor, viewport, edit mode (requires raylib)
  sass_re/     -- SASS reverse engineering: probes, microbench, instant-NGP kernels
  cuda_lbm/    -- D3Q19 precision-tier CUDA LBM kernels
  tools/       -- CLI utilities
  third_party/ -- stb_image_write.h
shaders/       -- GLSL compute shaders + compiled .spv
docs/          -- organized into sass/, nerf/, engine/, results/
scripts/       -- build, test, and analysis scripts
```

## Requirements

- **Required:** C11 compiler, pthreads, CMake 3.16+
- **Optional:** Vulkan SDK, raylib (editor), OpenMP, ONNX Runtime
- **SASS toolkit:** CUDA 13.x (SM 7.5+) or CUDA 12.x (Pascal), MSVC or GCC, Python 3

## License

MIT

## Contributing

Contributions are welcome via pull requests and issues.

For project history and original author attribution, see [ORIGINAL_AUTHOR.md](ORIGINAL_AUTHOR.md).
