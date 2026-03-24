/*
 * SASS RE Probe: TMU filtering, address modes, and surface boundary behavior
 *
 * Device-only kernel set used by the dedicated texture/surface runner.
 * This keeps the mnemonic census separate from the host-side CUDA array and
 * texture object setup needed for runtime validation.
 */

#include <cuda_runtime.h>

static __device__ __forceinline__ float tex_center_1d(int i, int n) {
    return ((float)i + 0.5f) / (float)n;
}

static __device__ __forceinline__ float tex_center_2d_x(int x, int w) {
    return ((float)x + 0.5f) / (float)w;
}

static __device__ __forceinline__ float tex_center_2d_y(int y, int h) {
    return ((float)y + 0.5f) / (float)h;
}

static __device__ __forceinline__ float tex_center_3d_z(int z, int d) {
    return ((float)z + 0.5f) / (float)d;
}

extern "C" __global__ void __launch_bounds__(128)
tmu_1d_point(float *out, cudaTextureObject_t tex, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float u = ((float)i + 0.25f) / (float)n;
    out[i] = tex1D<float>(tex, u);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_1d_linear(float *out, cudaTextureObject_t tex, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float u = ((float)i + 0.75f) / (float)n;
    out[i] = tex1D<float>(tex, u);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_1d_sample_coords(float *out, cudaTextureObject_t tex, const float *coords, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    out[i] = tex1D<float>(tex, coords[i]);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_2d_point(float *out, cudaTextureObject_t tex, int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= w || y >= h) return;
    float u = ((float)x + 0.25f) / (float)w;
    float v = ((float)y + 0.75f) / (float)h;
    out[y * w + x] = tex2D<float>(tex, u, v);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_2d_linear(float *out, cudaTextureObject_t tex, int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= w || y >= h) return;
    float u = ((float)x + 0.75f) / (float)w;
    float v = ((float)y + 0.75f) / (float)h;
    out[y * w + x] = tex2D<float>(tex, u, v);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_2d_sample_coords(float *out, cudaTextureObject_t tex, const float2 *coords, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float2 uv = coords[i];
    out[i] = tex2D<float>(tex, uv.x, uv.y);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_2d_manual_bilerp(float *out, cudaTextureObject_t tex, int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= w || y >= h) return;

    int x0 = x;
    int x1 = min(x + 1, w - 1);
    int y0 = y;
    int y1 = min(y + 1, h - 1);
    float fx = 0.25f;
    float fy = 0.25f;

    float v00 = tex2D<float>(tex, tex_center_2d_x(x0, w), tex_center_2d_y(y0, h));
    float v10 = tex2D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y0, h));
    float v01 = tex2D<float>(tex, tex_center_2d_x(x0, w), tex_center_2d_y(y1, h));
    float v11 = tex2D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y1, h));

    float ix0 = v00 + fx * (v10 - v00);
    float ix1 = v01 + fx * (v11 - v01);
    out[y * w + x] = ix0 + fy * (ix1 - ix0);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_3d_point(float *out, cudaTextureObject_t tex, int w, int h, int d) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int n = w * h * d;
    if (i >= n) return;
    int z = i / (w * h);
    int y = (i / w) % h;
    int x = i % w;
    float u = ((float)x + 0.20f) / (float)w;
    float v = ((float)y + 0.30f) / (float)h;
    float q = ((float)z + 0.40f) / (float)d;
    out[i] = tex3D<float>(tex, u, v, q);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_3d_linear(float *out, cudaTextureObject_t tex, int w, int h, int d) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int n = w * h * d;
    if (i >= n) return;
    int z = i / (w * h);
    int y = (i / w) % h;
    int x = i % w;
    float u = ((float)x + 0.75f) / (float)w;
    float v = ((float)y + 0.75f) / (float)h;
    float q = ((float)z + 0.75f) / (float)d;
    out[i] = tex3D<float>(tex, u, v, q);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_3d_manual_trilerp(float *out, cudaTextureObject_t tex, int w, int h, int d) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int n = w * h * d;
    if (i >= n) return;
    int z = i / (w * h);
    int y = (i / w) % h;
    int x = i % w;
    int x1 = min(x + 1, w - 1);
    int y1 = min(y + 1, h - 1);
    int z1 = min(z + 1, d - 1);
    float fx = 0.25f;
    float fy = 0.25f;
    float fz = 0.25f;

    float c000 = tex3D<float>(tex, tex_center_2d_x(x, w), tex_center_2d_y(y, h), tex_center_3d_z(z, d));
    float c100 = tex3D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y, h), tex_center_3d_z(z, d));
    float c010 = tex3D<float>(tex, tex_center_2d_x(x, w), tex_center_2d_y(y1, h), tex_center_3d_z(z, d));
    float c110 = tex3D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y1, h), tex_center_3d_z(z, d));
    float c001 = tex3D<float>(tex, tex_center_2d_x(x, w), tex_center_2d_y(y, h), tex_center_3d_z(z1, d));
    float c101 = tex3D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y, h), tex_center_3d_z(z1, d));
    float c011 = tex3D<float>(tex, tex_center_2d_x(x, w), tex_center_2d_y(y1, h), tex_center_3d_z(z1, d));
    float c111 = tex3D<float>(tex, tex_center_2d_x(x1, w), tex_center_2d_y(y1, h), tex_center_3d_z(z1, d));

    float x00 = c000 + fx * (c100 - c000);
    float x10 = c010 + fx * (c110 - c010);
    float x01 = c001 + fx * (c101 - c001);
    float x11 = c011 + fx * (c111 - c011);
    float y0 = x00 + fy * (x10 - x00);
    float y1v = x01 + fy * (x11 - x01);
    out[i] = y0 + fz * (y1v - y0);
}

extern "C" __global__ void __launch_bounds__(128)
tmu_surface_1d_copy(cudaSurfaceObject_t surf_in, cudaSurfaceObject_t surf_out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    float value = 0.0f;
    surf1Dread(&value, surf_in, i * (int)sizeof(float), cudaBoundaryModeClamp);
    surf1Dwrite(value + 3.0f, surf_out, i * (int)sizeof(float));
}

extern "C" __global__ void __launch_bounds__(128)
tmu_surface_2d_copy(cudaSurfaceObject_t surf_in, cudaSurfaceObject_t surf_out, int w, int h) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= w || y >= h) return;
    float value = 0.0f;
    surf2Dread(&value, surf_in, x * (int)sizeof(float), y, cudaBoundaryModeClamp);
    surf2Dwrite(value + 5.0f, surf_out, x * (int)sizeof(float), y);
}

extern "C" __global__ void __launch_bounds__(32)
tmu_surface_oob_zero(float *out, cudaSurfaceObject_t surf, int w, int h) {
    float value = 123.0f;
    surf2Dread(&value, surf, w * (int)sizeof(float), h, cudaBoundaryModeZero);
    out[0] = value;
}

extern "C" __global__ void __launch_bounds__(32)
tmu_surface_oob_clamp(float *out, cudaSurfaceObject_t surf, int w, int h) {
    float value = 0.0f;
    surf2Dread(&value, surf, w * (int)sizeof(float), h, cudaBoundaryModeClamp);
    out[0] = value;
}
