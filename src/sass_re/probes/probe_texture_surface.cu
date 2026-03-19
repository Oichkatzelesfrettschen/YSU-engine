/*
 * SASS RE Probe: Texture and Surface Operations
 * Isolates: TEX, TLD, TXQ, SULD, SUST, SUATOM
 *
 * The texture unit on Ada Lovelace is unified with L1 cache (128 KB/SM).
 * Texture fetches go through the L1TEX pipeline with hardware interpolation.
 * Surface operations provide read/write access to texture memory.
 *
 * Key SASS:
 *   TEX       -- texture fetch (filtered)
 *   TLD       -- texture load (unfiltered, direct access)
 *   TXQ       -- texture query (dimensions, mip levels)
 *   SULD      -- surface load
 *   SUST      -- surface store
 *   SUATOM    -- surface atomic
 *
 * These are critical for the NeRF/rendering pipeline in Instant-NGP
 * and for any kernel using texture cache for read-only data.
 */

#include <cuda_runtime.h>

// Texture object-based fetch (CUDA bindless texture)
// This is the modern API (no texture references)

// 1D float texture fetch
extern "C" __global__ void __launch_bounds__(32)
probe_tex_1d_float(float *out, cudaTextureObject_t tex, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    // TEX instruction: hardware-interpolated 1D fetch
    float val = tex1Dfetch<float>(tex, i);
    out[i] = val;
}

// 2D float texture fetch with bilinear interpolation
extern "C" __global__ void __launch_bounds__(32)
probe_tex_2d_float(float *out, cudaTextureObject_t tex, int w, int h) {
    int x = threadIdx.x + blockIdx.x * blockDim.x;
    int y = threadIdx.y + blockIdx.y * blockDim.y;
    if (x >= w || y >= h) return;

    // TEX with normalized coordinates + bilinear filtering
    float u = ((float)x + 0.5f) / (float)w;
    float v = ((float)y + 0.5f) / (float)h;
    float val = tex2D<float>(tex, u, v);
    out[y * w + x] = val;
}

// 3D texture fetch (used in volume rendering / NeRF density grids)
extern "C" __global__ void __launch_bounds__(32)
probe_tex_3d_float(float *out, cudaTextureObject_t tex,
                   int nx, int ny, int nz) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= nx * ny * nz) return;

    int z = i / (nx * ny);
    int y = (i / nx) % ny;
    int x = i % nx;

    float u = ((float)x + 0.5f) / (float)nx;
    float v = ((float)y + 0.5f) / (float)ny;
    float w = ((float)z + 0.5f) / (float)nz;
    float val = tex3D<float>(tex, u, v, w);
    out[i] = val;
}

// Texture fetch chain for latency measurement
extern "C" __global__ void __launch_bounds__(32)
probe_tex_chain(float *out, cudaTextureObject_t tex) {
    int i = threadIdx.x;
    float idx = (float)i;

    // Dependent texture fetch chain: result of one fetch indexes the next
    #pragma unroll 1
    for (int j = 0; j < 64; j++) {
        idx = tex1Dfetch<float>(tex, (int)idx % 1024);
    }
    out[i] = idx;
}

// Surface load and store (read-write texture memory)
extern "C" __global__ void __launch_bounds__(32)
probe_surface_load_store(cudaSurfaceObject_t surf_in,
                         cudaSurfaceObject_t surf_out, int w) {
    int x = threadIdx.x + blockIdx.x * blockDim.x;
    if (x >= w) return;

    // SULD: surface load
    float val;
    surf1Dread(&val, surf_in, x * sizeof(float));

    // Transform
    val = val * 2.0f + 1.0f;

    // SUST: surface store
    surf1Dwrite(val, surf_out, x * sizeof(float));
}

// Multiple texture fetches (simulates hash grid feature lookup)
extern "C" __global__ void __launch_bounds__(128)
probe_tex_multi_fetch(float *out, cudaTextureObject_t tex, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    // 8 independent texture fetches (simulates 8 hash grid corners)
    float v0 = tex1Dfetch<float>(tex, i);
    float v1 = tex1Dfetch<float>(tex, i + 1);
    float v2 = tex1Dfetch<float>(tex, i + 2);
    float v3 = tex1Dfetch<float>(tex, i + 3);
    float v4 = tex1Dfetch<float>(tex, i + n);
    float v5 = tex1Dfetch<float>(tex, i + n + 1);
    float v6 = tex1Dfetch<float>(tex, i + n + 2);
    float v7 = tex1Dfetch<float>(tex, i + n + 3);

    // Trilinear interpolation (7 lerps)
    float fx = 0.5f;
    float i0 = v0 + fx * (v1 - v0);
    float i1 = v2 + fx * (v3 - v2);
    float i2 = v4 + fx * (v5 - v4);
    float i3 = v6 + fx * (v7 - v6);
    float j0 = i0 + fx * (i1 - i0);
    float j1 = i2 + fx * (i3 - i2);
    out[i] = j0 + fx * (j1 - j0);
}
