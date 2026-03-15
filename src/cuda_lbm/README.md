# cuda_lbm -- D3Q19 Lattice Boltzmann GPU Kernels

Precision-tier CUDA kernels implementing the D3Q19 Lattice Boltzmann Method (LBM)
for YSU fluid simulation and physics subsystems. All kernels follow the
storage-compute split pattern: distributions are stored in a compressed precision
format, but arithmetic is promoted to FP32 or FP64 before any computation.

## Kernels

| File                   | Storage         | Bytes/dist | Stride | Key trick                                     | Min arch |
|------------------------|-----------------|------------|--------|-----------------------------------------------|----------|
| kernels_fp16.cu        | `__half`        | 2          | 20     | 10x half2 vectorized loads (padded stride)    | SM 7.0   |
| kernels_fp8.cu         | `__nv_fp8_e4m3` | 1          | 20     | 5x uchar4 vectorized loads (padded stride)    | SM 8.9   |
| kernels_int8.cu        | `signed char`   | 1          | 20     | 5x `__dp4a` momentum groups (padded stride)   | SM 6.1   |
| kernels_dd.cu          | `double[2]`     | 16         | i-major SoA | Knuth 2-sum + Veltkamp/Dekker FMA, coalesced | SM 6.0 |
| kernels_tensor_core.cu | WMMA frags      | N/A        | N/A    | WMMA mma_sync proxy (TF32/FP16/INT8/INT4)    | SM 7.0   |

## YSU Bandwidth-Reduction Tricks

All low-precision tiers exploit the fact that D3Q19 LBM is **memory-bandwidth
bound** at production grid sizes. The arithmetic rate on modern GPUs vastly
exceeds the memory bus, so reducing distribution storage from 4 bytes (FP32) to
1 byte (FP8/INT8) gives a 4x bandwidth increase -- which translates directly to
4x higher MLUPS (Million Lattice Updates Per Second).

### FP16 (kernels_fp16.cu)
- AoS stride=20 (padded from 19 to ensure 4-byte half2 alignment for all cells).
- 10x `half2` vectorized loads cover indices 0-19 with a bounds guard on slot 19.
- `__ldg()` read-only cache path on the input ping buffer.
- Horner FMA equilibrium: `f_eq = w_rho * fmaf(fmaf(eu, 4.5f, 3.0f), eu, base)`.
- VRAM at 128^3: 20 * 2,097,152 * 2 * 2 (ping+pong) = ~160 MB.
- Appropriate for moderate-density flows where the 10-bit mantissa is sufficient.

### FP8 e4m3 (kernels_fp8.cu)
- `__nv_fp8_storage_t` (CUDA 11.8+, SM 8.9 / Ada Lovelace only).
- AoS stride=20 (padded); 5x `uchar4` aligned loads cover all 20 slots with
  bounds guard on slot 19.
- Conversion path: `__half2float(__nv_cvt_fp8_to_halfraw(v, __NV_E4M3))`.
- VRAM at 128^3: 20 * 2,097,152 * 1 * 2 (ping+pong) = ~80 MB.
- Risk: 4-bit mantissa limits precision to qualitative flow features only.

### INT8 fixed-point (kernels_int8.cu)
- Scale factor: `DIST_SCALE = 64.0` (max representable f_i ~= 1.98 before clamp).
- AoS stride=20 (padded); 5x int32 loads cover all 20 slots with unpacking.
- 5x `__dp4a(a_i8x4, b_i8x4, acc)` groups (indices 0-19; slot 19 has velocity 0
  so its dp4a contribution is exactly zero -- no special casing needed).
- VRAM at 128^3: 20 * 2,097,152 * 1 * 2 (ping+pong) = ~80 MB.
- Risk: saturation at high density contrasts (rho >> 1).

### Double-Double FP128 (kernels_dd.cu)
- Each distribution stored as `(hi: double, lo: double)` pairs -- 16 bytes each.
- Layout: i-major SoA -- `f_hi[i * n_cells + idx]`. Within distribution lane i,
  a warp accesses consecutive doubles: fully coalesced 256-byte transactions.
  Scatter writes `f_hi_out[i * n_cells + idx_next]` are coalesced for
  x-direction streaming and nearly coalesced for y/z/diagonal directions.
- Four device buffers: `f_hi_a`, `f_lo_a` (ping), `f_hi_b`, `f_lo_b` (pong).
- ~106-bit mantissa via Knuth 2-sum (`two_sum`) and Veltkamp/Dekker
  (`two_prod` + FMA residual).
- Expected throughput: ~64:1 speed penalty vs FP32 (FP64 register pressure).
- VRAM at 128^3: 19 * 2,097,152 * 16 (4 bufs * 8 bytes) = ~1215 MB.
- Use for: accuracy validation, long-time spectral diagnostics.

### Tensor Core WMMA Proxy (kernels_tensor_core.cu)
- NOT an LBM kernel -- measures raw Tensor Core GFLOPS as a headroom benchmark.
- Shapes: TF32 (16x16x8), FP16 (16x16x16), INT8 (16x16x16), INT4 (8x8x32).
- Quantifies the gap between bandwidth-bound custom LBM and TC peak throughput.
- Useful for deciding whether a matrix-reformulation of the collision step
  (e.g., Hermite-expansion BGK as matrix-vector) could exploit TC acceleration.

## Kernel API

All step/init kernels follow the same signature pattern:

```c
extern "C" __global__ void lbm_step_fused_<tier>_kernel(
    const <storage_t>* f_in,   // ping buffer
    <storage_t>* f_out,        // pong buffer
    float* rho_out,            // macroscopic density (always FP32)
    float* u_out,              // macroscopic velocity (always FP32, 3*n_cells)
    const float* force,        // body force (FP32)
    const float* tau,          // relaxation time (FP32, per-cell)
    int nx, int ny, int nz
);

extern "C" __global__ void initialize_uniform_<tier>_kernel(
    <storage_t>* f,
    float* rho_out, float* u_out, float* tau,
    float rho_init, float ux_init, float uy_init, float uz_init,
    float tau_val, int nx, int ny, int nz
);
```

Double-double uses separate `f_hi` / `f_lo` pointers instead of a single `f`.

## Launch Configuration

- FP16, FP8, INT8: 1024 threads/block, blocks = ceil(n_cells / 1024).
- DD: 128 threads/block (FP64 register pressure limits occupancy).
- Tensor Core proxy: 32 threads/block, `__launch_bounds__(32, 1)` enforces exactly
  1 warp per block; n_tiles blocks. One WMMA tile (M*N output) per block/warp.

## Ada SM 8.9 Performance Estimates (RTX 4070 Ti, 504 GB/s peak)

| Tier   | Bytes/dist | Stride | VRAM at 128^3 | Relative BW | Expected MLUPS (128^3) |
|--------|-----------|--------|---------------|-------------|------------------------|
| FP32   | 4         | 19     | ~305 MB       | 1x          | ~200                   |
| BF16   | 2         | 19     | ~152 MB       | 2x          | ~400                   |
| FP16   | 2         | 20*    | ~160 MB       | 2x          | ~400                   |
| FP8    | 1         | 20*    | ~80 MB        | 4x          | ~800 (SM 8.9 only)     |
| INT8   | 1         | 20*    | ~80 MB        | 4x          | ~800                   |
| FP64   | 8         | 19     | ~609 MB       | 0.5x        | ~3 (64:1 FLOP ratio)   |
| DD     | 16        | i-SoA  | ~1215 MB      | 0.25x       | ~0.05 (accuracy tier)  |

(*) Padded from 19 to 20 to guarantee 4-byte alignment for vectorized loads.
