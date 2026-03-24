/*
 * SASS RE Probe: 2D Stencil Tiling Patterns
 * Isolates: Shared memory tiled stencils with various halo widths
 *
 * Tests 5-point, 9-point, and 25-point stencils with shared memory tiling.
 * Measures the SASS cost of halo loading, __syncthreads barriers, and
 * shared memory access patterns for different stencil radii.
 *
 * Patterns from production LBM (8x8x4 tiles) and NeRF (hash grid tiles).
 */

// 5-point 2D stencil (radius=1): 16x16 tile + 1-cell halo = 18x18 smem
extern "C" __global__ void __launch_bounds__(256)
probe_tile_5pt_r1(float *out, const float *in, int nx, int ny) {
    __shared__ float s[18][18];
    int tx = threadIdx.x % 16, ty = threadIdx.x / 16;
    int gx = blockIdx.x * 16 + tx, gy = blockIdx.y * 16 + ty;

    // Load interior
    if (gx < nx && gy < ny)
        s[ty+1][tx+1] = in[gy * nx + gx];

    // Load halos
    if (tx == 0 && gx > 0)     s[ty+1][0] = in[gy * nx + gx - 1];
    if (tx == 15 && gx+1 < nx) s[ty+1][17] = in[gy * nx + gx + 1];
    if (ty == 0 && gy > 0)     s[0][tx+1] = in[(gy-1) * nx + gx];
    if (ty == 15 && gy+1 < ny) s[17][tx+1] = in[(gy+1) * nx + gx];
    __syncthreads();

    if (gx > 0 && gx < nx-1 && gy > 0 && gy < ny-1) {
        out[gy*nx+gx] = 0.2f * (s[ty+1][tx+1] + s[ty][tx+1] + s[ty+2][tx+1]
                               + s[ty+1][tx] + s[ty+1][tx+2]);
    }
}

// 9-point 2D stencil (radius=1, includes diagonals)
extern "C" __global__ void __launch_bounds__(256)
probe_tile_9pt_r1(float *out, const float *in, int nx, int ny) {
    __shared__ float s[18][18];
    int tx = threadIdx.x % 16, ty = threadIdx.x / 16;
    int gx = blockIdx.x * 16 + tx, gy = blockIdx.y * 16 + ty;

    if (gx < nx && gy < ny) s[ty+1][tx+1] = in[gy * nx + gx];

    // Full halo (edges + corners)
    if (tx == 0) {
        if (gx > 0) s[ty+1][0] = in[gy*nx+gx-1];
        if (gx > 0 && ty == 0 && gy > 0) s[0][0] = in[(gy-1)*nx+gx-1];
    }
    if (tx == 15) {
        if (gx+1 < nx) s[ty+1][17] = in[gy*nx+gx+1];
        if (gx+1 < nx && ty == 0 && gy > 0) s[0][17] = in[(gy-1)*nx+gx+1];
    }
    if (ty == 0 && gy > 0) s[0][tx+1] = in[(gy-1)*nx+gx];
    if (ty == 15 && gy+1 < ny) s[17][tx+1] = in[(gy+1)*nx+gx];
    __syncthreads();

    if (gx > 0 && gx < nx-1 && gy > 0 && gy < ny-1) {
        float center = s[ty+1][tx+1];
        float cross = s[ty][tx+1] + s[ty+2][tx+1] + s[ty+1][tx] + s[ty+1][tx+2];
        float diag = s[ty][tx] + s[ty][tx+2] + s[ty+2][tx] + s[ty+2][tx+2];
        out[gy*nx+gx] = 0.2f * center + 0.15f * cross + 0.05f * diag;
    }
}

// 25-point stencil (radius=2): 16x16 tile + 2-cell halo = 20x20 smem
extern "C" __global__ void __launch_bounds__(256)
probe_tile_25pt_r2(float *out, const float *in, int nx, int ny) {
    __shared__ float s[20][20];
    int tx = threadIdx.x % 16, ty = threadIdx.x / 16;
    int gx = blockIdx.x * 16 + tx, gy = blockIdx.y * 16 + ty;

    // Interior
    int gi = gy * nx + gx;
    if (gx < nx && gy < ny) s[ty+2][tx+2] = in[gi];

    // Cooperative halo load (all threads help)
    for (int h = threadIdx.x; h < 20*20; h += blockDim.x) {
        int hy = h / 20, hx = h % 20;
        int hgx = blockIdx.x * 16 + hx - 2;
        int hgy = blockIdx.y * 16 + hy - 2;
        if (hgx >= 0 && hgx < nx && hgy >= 0 && hgy < ny)
            s[hy][hx] = in[hgy * nx + hgx];
        else
            s[hy][hx] = 0.0f;
    }
    __syncthreads();

    if (gx >= 2 && gx < nx-2 && gy >= 2 && gy < ny-2) {
        float sum = 0.0f;
        #pragma unroll
        for (int dy = -2; dy <= 2; dy++)
            for (int dx = -2; dx <= 2; dx++)
                sum += s[ty+2+dy][tx+2+dx];
        out[gi] = sum / 25.0f;
    }
}

// 3D tile: 8x8x4 (from D3Q19 LBM tiled pull-scheme)
extern "C" __global__ void __launch_bounds__(256)
probe_tile_3d_8x8x4(float *out, const float *in, int nx, int ny, int nz) {
    // 10x10x6 shared memory (8x8x4 + 1-cell halo on each side)
    __shared__ float s[6][10][10];

    int tx = threadIdx.x % 8;
    int ty = (threadIdx.x / 8) % 8;
    int tz = threadIdx.x / 64;

    int bx = blockIdx.x * 8, by = blockIdx.y * 8, bz = blockIdx.z * 4;
    int gx = bx + tx, gy = by + ty, gz = bz + tz;

    // Load interior
    if (gx < nx && gy < ny && gz < nz)
        s[tz+1][ty+1][tx+1] = in[gz*ny*nx + gy*nx + gx];

    // Cooperative halo load
    if (tx == 0 && gx > 0)     s[tz+1][ty+1][0] = in[gz*ny*nx + gy*nx + gx-1];
    if (tx == 7 && gx+1 < nx)  s[tz+1][ty+1][9] = in[gz*ny*nx + gy*nx + gx+1];
    if (ty == 0 && gy > 0)     s[tz+1][0][tx+1] = in[gz*ny*nx + (gy-1)*nx + gx];
    if (ty == 7 && gy+1 < ny)  s[tz+1][9][tx+1] = in[gz*ny*nx + (gy+1)*nx + gx];
    if (tz == 0 && gz > 0)     s[0][ty+1][tx+1] = in[(gz-1)*ny*nx + gy*nx + gx];
    if (tz == 3 && gz+1 < nz)  s[5][ty+1][tx+1] = in[(gz+1)*ny*nx + gy*nx + gx];
    __syncthreads();

    if (gx > 0 && gx < nx-1 && gy > 0 && gy < ny-1 && gz > 0 && gz < nz-1) {
        // 7-point 3D stencil
        out[gz*ny*nx + gy*nx + gx] =
            (s[tz+1][ty+1][tx+1] * 0.5f +
             s[tz+1][ty+1][tx] + s[tz+1][ty+1][tx+2] +
             s[tz+1][ty][tx+1] + s[tz+1][ty+2][tx+1] +
             s[tz][ty+1][tx+1] + s[tz+2][ty+1][tx+1]) / 6.5f;
    }
}

// Double-buffered 3D tile with async copy (cp.async)
#include <cuda_pipeline.h>

extern "C" __global__ void __launch_bounds__(64)
probe_tile_3d_async(float *out, const float *in, int nx, int ny, int nz) {
    __shared__ float buf[2][10][10];
    int tx = threadIdx.x % 8, ty = (threadIdx.x / 8) % 8;
    int bx = blockIdx.x * 8, by = blockIdx.y * 8;
    int gx = bx + tx, gy = by + ty;

    // Process Z slices with double buffering
    // Load first slice via cp.async
    if (gx < nx && gy < ny) {
        __pipeline_memcpy_async(&buf[0][ty+1][tx+1], &in[gy*nx + gx], sizeof(float));
    }
    __pipeline_commit();

    for (int gz = 1; gz < nz - 1; gz++) {
        int cur = (gz - 1) & 1;
        int nxt = gz & 1;

        // Async load next Z slice
        if (gx < nx && gy < ny) {
            __pipeline_memcpy_async(&buf[nxt][ty+1][tx+1], &in[gz*ny*nx + gy*nx + gx], sizeof(float));
        }
        __pipeline_commit();
        __pipeline_wait_prior(1);
        __syncthreads();

        // Compute on current slice (simplified 2D stencil per Z)
        if (gx > 0 && gx < nx-1 && gy > 0 && gy < ny-1) {
            out[(gz-1)*ny*nx + gy*nx + gx] =
                0.5f * buf[cur][ty+1][tx+1] +
                0.125f * (buf[cur][ty][tx+1] + buf[cur][ty+2][tx+1] +
                          buf[cur][ty+1][tx] + buf[cur][ty+1][tx+2]);
        }
        __syncthreads();
    }

    // Drain last slice
    __pipeline_wait_prior(0);
    __syncthreads();
    int last = (nz - 2) & 1;
    if (gx > 0 && gx < nx-1 && gy > 0 && gy < ny-1) {
        out[(nz-2)*ny*nx + gy*nx + gx] = buf[last][ty+1][tx+1];
    }
}
