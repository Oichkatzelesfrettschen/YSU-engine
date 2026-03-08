# GPU Denoiser Optimization Quick Reference

## Environment Variables

### Rendering Control
| Variable | Default | Range | Purpose |
|----------|---------|-------|---------|
| `YSU_GPU_W` | 4096 | 320-4096 | Output width |
| `YSU_GPU_H` | 2048 | 180-2048 | Output height |
| `YSU_GPU_SPP` | 128 | 1-1024 | Samples per pixel |
| `YSU_GPU_FRAMES` | 1 | 1-N | Frames to render |
| `YSU_GPU_RENDER_SCALE` | 1.0 | 0.1-1.0 | Render resolution multiplier |

### Denoiser Control
| Variable | Default | Purpose |
|----------|---------|---------|
| `YSU_GPU_DENOISE` | 0 | Enable GPU denoiser (bilateral filter) |
| `YSU_GPU_DENOISE_RADIUS` | 3* | Filter kernel radius (1-5) |
| `YSU_GPU_DENOISE_SIGMA_S` | 1.5* | Spatial standard deviation |
| `YSU_GPU_DENOISE_SIGMA_R` | 0.1* | Range standard deviation |
| `YSU_NEURAL_DENOISE` | 0 | Disable CPU neural denoiser |

*Automatically reduced in FAST mode (radius→1, sigma_s→0.8, sigma_r→0.05)

### Performance Optimization
| Variable | Default | Purpose |
|----------|---------|---------|
| `YSU_GPU_FAST` | 0 | Aggressive optimization (auto 50% scale, reduced denoise) |
| `YSU_GPU_MINIMAL` | 0 | Bare kernel test (1 frame, 1 spp, no I/O) |
| `YSU_GPU_NO_IO` | 0 | Skip readback/file writes |
| `YSU_GPU_TS` | 0 | Enable GPU timestamp queries |

### Output Control
| Variable | Default | Purpose |
|----------|---------|---------|
| `YSU_GPU_WRITE` | 1 | Write output_gpu.ppm |
| `YSU_GPU_READBACK` | depends | GPU→CPU readback |
| `YSU_GPU_TONEMAP` | auto | Tonemap to LDR |
| `YSU_GPU_WINDOW` | 0 | Display in window |

## Usage Examples

### Quick Test (5 FPS)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=4 YSU_GPU_FRAMES=1 ./gpu_demo.exe
```

### Interactive Realtime (~25 FPS)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=1 YSU_GPU_FRAMES=4 \
YSU_GPU_DENOISE=1 YSU_GPU_DENOISE_RADIUS=2 ./gpu_demo.exe
```

### Fast Mode (Half-Res, Optimized Denoise)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_FAST=1 \
YSU_GPU_DENOISE=1 ./gpu_demo.exe
# Auto: 960×540 render, denoise radius=1, 25 FPS
```

### Ultra-Fast (Quarter-Res)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_RENDER_SCALE=0.25 \
YSU_GPU_SPP=1 YSU_GPU_DENOISE=1 ./gpu_demo.exe
# 480×270 render (upscale to 1080p display)
```

### Debug with Timestamps (Measure GPU Cost)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=1 YSU_GPU_FRAMES=1 \
YSU_GPU_DENOISE=1 YSU_GPU_TS=1 YSU_GPU_NO_IO=1 ./gpu_demo.exe
# Prints: [GPU][denoise] h=X.XXX ms v=Y.YYY ms per frame
```

### Benchmarking (Isolated Compute)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=1 YSU_GPU_FRAMES=4 \
YSU_GPU_MINIMAL=1 YSU_GPU_DENOISE=1 ./gpu_demo.exe
# Measures: render + denoise with minimal overhead
```

## Performance Profile (1920×1080, 1 SPP)

| Component | Time | Notes |
|-----------|------|-------|
| **Vulkan Overhead** | ~90ms | Init, barriers, readback (unavoidable) |
| **Render Dispatch** | ~5-10ms | Main raytracing |
| **Denoise (r=3)** | ~4-5ms | Separable bilateral filter |
| **Tonemap/UI** | ~1-2ms | Optional |
| **Total** | ~100-105ms | ~10 FPS raw, or 2.5 frames/100ms |

## Quality vs Performance Trade-offs

### High Quality (Slow)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=32 \
YSU_GPU_DENOISE=1 YSU_GPU_DENOISE_RADIUS=3 YSU_GPU_FRAMES=1
# 32 samples, full denoise, takes ~100ms per frame
```

### Balanced (Medium)
```bash
YSU_GPU_W=1920 YSU_GPU_H=1080 YSU_GPU_SPP=4 \
YSU_GPU_DENOISE=1 YSU_GPU_DENOISE_RADIUS=2 YSU_GPU_FRAMES=1
```

### Realtime (Fast)
```bash
YSU_GPU_FAST=1 YSU_GPU_W=1920 YSU_GPU_H=1080 \
YSU_GPU_DENOISE=1 YSU_GPU_FRAMES=4
# 960×540, 1 sample, light denoise, ~25 FPS
```

## Troubleshooting

**Slow performance**: Check if `YSU_NEURAL_DENOISE=1` (CPU denoiser, ~150ms). Set to 0.

**No speedup from RENDER_SCALE**: Vulkan overhead dominates. Use FAST mode instead.

**GPU timeout**: Reduce SPP or use smaller resolution.

**High VRAM usage**: Denoise temp image is WxH×16 bytes. Half-res saves 75% denoise memory.

## Future Optimizations

1. **Async compute** - Run denoise on separate queue (est. -5ms)
2. **Temporal denoise** - Only denoise every 2nd frame (est. -2-3ms)
3. **Reduced precision** - FP16 compute (est. -10% but less precision)
4. **Native CUDA** - Switch to CUDA/OptiX (est. -50ms but different API)
