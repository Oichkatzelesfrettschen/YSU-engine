/*
 * SASS RE Probe: Warp-Cooperative Tiling (no __syncthreads)
 * Isolates: Patterns that use warp-level sync instead of block barriers
 *
 * When tile size <= 32 (warp size), no __syncthreads is needed.
 * This removes BAR.SYNC entirely and replaces with implicit warp
 * synchronization or explicit __syncwarp.
 */

// Warp-level 1D stencil (32 elements, no barrier)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_tile_1d(float *out, const float *in, int n) {
    int lane = threadIdx.x;
    int base = blockIdx.x * 32;
    int gx = base + lane;
    if (gx >= n) return;

    float val = in[gx];
    // Neighbors via warp shuffle (no shared memory!)
    float left = __shfl_up_sync(0xFFFFFFFF, val, 1);
    float right = __shfl_down_sync(0xFFFFFFFF, val, 1);

    if (lane == 0) left = (gx > 0) ? in[gx - 1] : val;
    if (lane == 31) right = (gx < n-1) ? in[gx + 1] : val;

    out[gx] = 0.25f * left + 0.5f * val + 0.25f * right;
}

// Warp-level 2D stencil (using shuffle for neighbor exchange)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_tile_2d_shfl(float *out, const float *in, int nx, int ny) {
    // Map 32 lanes to 8x4 sub-tile
    int lane = threadIdx.x;
    int tx = lane % 8, ty = lane / 8;
    int bx = blockIdx.x * 8, by = blockIdx.y * 4;
    int gx = bx + tx, gy = by + ty;
    if (gx >= nx || gy >= ny) return;

    float val = in[gy * nx + gx];

    // X neighbors via shuffle (stride 1 within each row of 8)
    float left = __shfl_sync(0xFFFFFFFF, val, (lane & ~7) | ((tx - 1) & 7));
    float right = __shfl_sync(0xFFFFFFFF, val, (lane & ~7) | ((tx + 1) & 7));

    // Y neighbors via shuffle (stride 8)
    float up = __shfl_sync(0xFFFFFFFF, val, lane - 8);
    float down = __shfl_sync(0xFFFFFFFF, val, lane + 8);

    // Boundary handling
    if (tx == 0) left = (gx > 0) ? in[gy * nx + gx - 1] : val;
    if (tx == 7) right = (gx < nx-1) ? in[gy * nx + gx + 1] : val;
    if (ty == 0) up = (gy > 0) ? in[(gy-1) * nx + gx] : val;
    if (ty == 3) down = (gy < ny-1) ? in[(gy+1) * nx + gx] : val;

    out[gy * nx + gx] = 0.2f * (val + left + right + up + down);
}

// Warp-level reduction tile (warp processes a row, reduces to single value)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_tile_row_reduce(float *out, const float *in, int nx, int ny) {
    int row = blockIdx.x;
    if (row >= ny) return;
    int lane = threadIdx.x;

    float acc = 0.0f;
    // Each lane processes nx/32 elements
    for (int x = lane; x < nx; x += 32)
        acc += in[row * nx + x];

    // Warp butterfly reduction (no shared memory, no barrier)
    acc += __shfl_xor_sync(0xFFFFFFFF, acc, 16);
    acc += __shfl_xor_sync(0xFFFFFFFF, acc, 8);
    acc += __shfl_xor_sync(0xFFFFFFFF, acc, 4);
    acc += __shfl_xor_sync(0xFFFFFFFF, acc, 2);
    acc += __shfl_xor_sync(0xFFFFFFFF, acc, 1);

    if (lane == 0) out[row] = acc;
}

// Warp-tiled matrix multiply (32x32 tile, 1 warp)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_tile_matmul(float *C, const float *A, const float *B,
                       int M, int N, int K) {
    int lane = threadIdx.x;
    int row = blockIdx.y * 32 + lane;
    if (row >= M) return;

    // Each lane computes one row of output
    for (int col = 0; col < N; col++) {
        float acc = 0.0f;
        for (int k = 0; k < K; k++)
            acc = fmaf(A[row * K + k], B[k * N + col], acc);
        C[row * N + col] = acc;
    }
}
