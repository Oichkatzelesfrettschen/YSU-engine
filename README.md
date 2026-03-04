# YSU Engine

C-based raytracer, GPU compute engine, mesh editor, and physics simulator.

## Quick Start

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

CMake auto-detects Vulkan, raylib, OpenMP, AVX2. Missing deps skip those targets.

### Run

```bash
# CPU raytracer (low samples, fast)
YSU_W=320 YSU_H=180 YSU_SPP=4 ./build/bin/ysu

# With adaptive sampling + denoising
YSU_ADAPTIVE=1 YSU_NEURAL_DENOISE=1 ./build/bin/ysu
```

## Project Structure

```
src/
  core/        — vec2-4, ray, camera, sphere, triangle, image, material, color
  render/      — CPU renderer, BVH, scene loader, G-buffer, ysu_main.c
  denoise/     — bilateral, neural, ONNX denoiser
  nerf/        — NeRF SIMD inference, hash grid, batch scheduler
  vulkan/      — Vulkan compute pipelines, LBVH, GPU BVH
  physics/     — quantum volume, nuclear fission/fusion, reactor thermal
  editor/      — mesh editor, viewport, edit mode (requires raylib)
  upscale/     — neural upscaling
  tools/       — CLI utilities (inspect_ppm, ysub_info, ysub_to_ppm)
  third_party/ — stb_image_write.h
shaders/       — GLSL compute shaders + compiled .spv
docs/          — documentation
scripts/       — build, test, and analysis scripts
DATA/          — scene files, binary data
models/        — pretrained NeRF models
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `YSU_W` | 800 | Image width |
| `YSU_H` | 600 | Image height |
| `YSU_SPP` | 64 | Samples per pixel |
| `YSU_DEPTH` | 10 | Max bounce depth |
| `YSU_THREADS` | auto | Thread count |
| `YSU_TILE` | 32 | Tile size for MT renderer |
| `YSU_ADAPTIVE` | 0 | Enable adaptive sampling |
| `YSU_NEURAL_DENOISE` | 0 | Enable neural denoiser |
| `YSU_FOG` | 0 | Enable fog |

## Requirements

- **Required:** C11 compiler (GCC/Clang/MSVC), pthreads, CMake 3.16+
- **Optional:** Vulkan SDK (GPU targets), raylib (editor), OpenMP (NeRF batch), ONNX Runtime (neural denoise)
