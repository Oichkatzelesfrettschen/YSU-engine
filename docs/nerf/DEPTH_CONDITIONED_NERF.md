# Depth-Conditioned Heterogeneous NeRF: CPU-Guided Sparse Sampling

## Research Implementation for TÜBİTAK Project

### Overview
This document describes the implementation of a novel depth-conditioned NeRF rendering approach that uses CPU-computed depth hints to accelerate GPU volume rendering by focusing samples near actual surfaces.

### Concept
Traditional NeRF volume rendering samples uniformly along rays from t_near to t_far. This wastes computation on empty space. Our approach:

1. **CPU Prepass**: March through a coarse occupancy grid (64^3) on CPU to find first surface hit per ray
2. **Depth Hints Buffer**: Store (depth, delta, confidence, flags) per pixel in GPU buffer
3. **Narrow Band Sampling**: GPU samples only [depth-delta, depth+delta] instead of full [2,6] range
4. **Dynamic Step Reduction**: Use fewer MLP evaluations when narrow band is active

### Performance Results (RTX GPU, 2048x1024, Lego Scene)

| Mode | FPS | Notes |
|------|-----|-------|
| Mode 3 (Baseline) | 39.9 | Full [2,6] range, 32 steps |
| Mode 26 (Depth-Conditioned) | 44.5 | Sparse sampling, 8-32 steps |

**Speedup: 11% with 6% hit rate** (sparse 5k-iteration model)

Projected with fully trained model (30-50% hit rate): **1.3-1.5x speedup**

### Files Modified

#### gpu_vulkan_demo.c
- Added `DepthHintVec4` struct for CPU-side depth hints
- Added `occ_sample_cpu()` for occupancy grid sampling
- Added `compute_depth_hints_occ()` for CPU depth prepass
- Added binding 10 descriptor for depth hints buffer
- Added deferred depth prepass logic (only when camera stationary)

#### shaders/tri.comp
- Added `depthHints` SSBO at binding 10
- Added `nerf_depth_conditioned_integrate()` function
- Dynamic step count based on range width
- Mode 26 uses depth hints, mode 27 for debug visualization

### Usage

```bash
# Set environment variables
$env:YSU_GPU_WINDOW=1
$env:YSU_RENDER_MODE=26
$env:YSU_NERF_HASHGRID="models/lego_35k.bin"
$env:YSU_NERF_OCC="models/lego_35k_occ.bin"

# Run
./gpu_demo.exe
```

### Key Optimizations

1. **Deferred Prepass**: Depth hints only computed when camera is stationary for 5+ frames
2. **Hint Invalidation**: Buffer cleared during camera movement (fallback to full range)
3. **Proportional Steps**: Narrow band uses 8 steps vs 32 for full range (4x fewer MLP evals)
4. **Memory-Mapped Buffer**: Depth hints buffer kept mapped for efficient CPU updates

### Future Improvements

1. **GPU Depth Prepass**: Move occupancy marching to compute shader for faster updates
2. **Async Prepass**: Run CPU prepass on background thread
3. **Temporal Hints**: Reproject previous frame hints for immediate speedup
4. **Higher Resolution OCC**: 128^3 or 256^3 occupancy for tighter bounds

### Mathematical Analysis

For a pixel with depth hint confidence > 0.5:
- Original range: 4.0 units (t_near=2, t_far=6)
- Narrow range: ~1.0 units (hint_depth ± 0.5)
- Range reduction: 4x
- Step reduction: 32 → 8 = 4x
- MLP evaluations saved: 24 per pixel

For N% hit rate:
- Overall speedup ≈ 1 / (1 - N + N/4) = 1 / (1 - 0.75*N)
- 6% hit: 1.047x (observed: 1.11x)
- 30% hit: 1.29x (projected)
- 50% hit: 1.60x (projected)

### Conclusion

The depth-conditioned NeRF approach successfully reduces GPU MLP evaluations by focusing samples near surfaces. With a fully trained model and 30-50% depth hint coverage, we expect 1.3-1.6x speedup, contributing to the 60 FPS real-time rendering goal.

---
*Implementation: January 2026*
*TÜBİTAK Research Project: Real-Time Heterogeneous Neural Rendering*
