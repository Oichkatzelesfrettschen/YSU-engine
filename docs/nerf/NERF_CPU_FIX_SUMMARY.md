# NeRF CPU Renderer Fix Summary

## Problem
The CPU SIMD NeRF renderer was producing washed-out, uniform gray/brown images instead of the expected yellow lego bulldozer with black background.

## Root Causes Found and Fixed

### 1. MLP Weight Layout (Critical)
**File:** `nerf_simd.c` lines 457-493

**Issue:** Weights were stored in column-major `[in, out]` order but code was reading as row-major `[out, in]`.

**Fix:** Transposed weight indexing:
```c
// Before (wrong)
sum += w0[h * in_dim + i] * features_in[ray][i];

// After (correct)
sum += w0[i * hidden_dim + h] * features_in[ray][i];
```

### 2. Missing Trilinear Interpolation (Critical)
**File:** `nerf_simd.c` lines 663-720

**Issue:** Hashgrid lookup was using nearest-neighbor (single voxel) instead of 8-corner trilinear interpolation.

**Fix:** Implemented full trilinear interpolation:
- Hash all 8 corners (v000, v001, v010, v011, v100, v101, v110, v111)
- Compute fractional weights (wx, wy, wz)
- Lerp in Z, then Y, then X

### 3. Position Normalization Mismatch (Critical)
**File:** `nerf_simd.c` lines 663-677

**Issue:** GPU shader uses `pn = pl * 0.5 + 0.5` to convert from [-1,1] to [0,1], but CPU was using raw [-1,1] coordinates.

**Fix:** Added proper normalization matching GPU shader:
```c
// Convert to [0, 1] and clamp
pn.x = fmaxf(0.0f, fminf(1.0f, norm_pos.x * 0.5f + 0.5f));
pn.y = fmaxf(0.0f, fminf(1.0f, norm_pos.y * 0.5f + 0.5f));
pn.z = fmaxf(0.0f, fminf(1.0f, norm_pos.z * 0.5f + 0.5f));
```

### 4. Sigma Activation (Minor)
**File:** `nerf_simd.c` lines 503-515

**Issue:** ReLU activation was zeroing out sigma for negative MLP outputs.

**Fix:** Changed to softplus: `sigma = log(1 + exp(x))`

## Results

| Metric | Before | After |
|--------|--------|-------|
| Background | Uniform gray/brown | 89.8% black pixels |
| Object visibility | None | Clear yellow lego |
| Center pixel | (0.96, 0.91, 0.74) | (190, 177, 112) |
| Color | Washed out | R>G>B (golden/tan) |

## Build and Test Commands

```powershell
# Build
gcc -std=c11 -O2 -pthread -o ysu.exe ysu_main.c render.c vec3.c ray.c camera.c image.c sphere.c triangle.c bvh.c material.c color.c denoise.c bilateral_denoise.c postprocess.c gbuffer_dump.c nerf_simd.c nerf_simd_integration.c ysu_360_engine_integration.c sceneloader.c triangle_hit_asm.o -lm -lws2_32 -Wno-implicit-function-declaration

# Run
$env:YSU_W="640"; $env:YSU_H="360"
$env:YSU_NERF_HASHGRID="models/nerf_hashgrid.bin"
$env:YSU_NERF_OCC="models/nerf_occ.bin"
$env:YSU_NERF_STEPS="64"
$env:YSU_NERF_BOUNDS="1.5"
$env:YSU_NERF_EXPOSURE="2.0"
.\ysu.exe
```

## Output Files
- `nerf_debug.ppm` - Raw NeRF framebuffer
- `nerf_debug_scaled.png` - Tonemapped PNG with exposure
- `nerf_alpha.png` - Alpha/density channel
- `output.png` - Final output

## Lessons Learned
1. Always verify weight layout (row-major vs column-major) matches the training code
2. Trilinear interpolation is essential for smooth NeRF rendering
3. Position normalization must match exactly between GPU and CPU implementations
4. Compare intermediate values (features, MLP outputs) to isolate issues
