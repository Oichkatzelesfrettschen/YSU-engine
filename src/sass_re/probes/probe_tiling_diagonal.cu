/*
 * SASS RE Probe: Diagonal and Skewed Tiling Patterns
 * Isolates: Non-rectangular tile shapes, diamond tiling, skewed access
 *
 * Standard rectangular tiles have aligned halo regions. Diagonal/skewed
 * tiles rotate the access pattern to reduce halo width for specific
 * stencil shapes (e.g., diamond tiling for wave-front parallelism).
 *
 * These patterns exercise unusual index arithmetic (IMAD with non-power-of-2
 * strides, modular arithmetic, conditional addressing) that may generate
 * different SASS instruction variants.
 */

// Diamond tile: rotated 45-degree 2D tile
extern "C" __global__ void __launch_bounds__(128)
probe_tile_diamond(float *out, const float *in, int nx, int ny) {
    // Diamond tile: thread (tx,ty) maps to grid (tx+ty, ty-tx+nx/2)
    int tx = threadIdx.x % 16;
    int ty = threadIdx.x / 16;
    int bx = blockIdx.x * 16, by = blockIdx.y * 8;

    // Rotated coordinates
    int gx = bx + tx + ty;
    int gy = by + ty - tx + 8;

    if (gx >= 0 && gx < nx && gy >= 0 && gy < ny) {
        float center = in[gy * nx + gx];
        float sum = center;

        // 4 diamond neighbors
        if (gx > 0) sum += in[gy * nx + gx - 1];
        if (gx < nx-1) sum += in[gy * nx + gx + 1];
        if (gy > 0) sum += in[(gy-1) * nx + gx];
        if (gy < ny-1) sum += in[(gy+1) * nx + gx];

        out[gy * nx + gx] = sum * 0.2f;
    }
}

// Skewed tile: trapezoidal access for time-tiling
extern "C" __global__ void __launch_bounds__(128)
probe_tile_skewed(float *out, const float *in, int nx, int timesteps) {
    __shared__ float s[2][130];  // Double-buffered, +2 halo
    int tx = threadIdx.x;
    int bx = blockIdx.x * 128;
    int gx = bx + tx;

    // Load initial condition
    if (gx < nx) s[0][tx + 1] = in[gx];
    if (tx == 0 && gx > 0) s[0][0] = in[gx - 1];
    if (tx == 127 && gx + 1 < nx) s[0][129] = in[gx + 1];
    __syncthreads();

    // Time-tile: multiple timesteps within one kernel launch
    for (int t = 0; t < timesteps; t++) {
        int cur = t & 1, nxt = (t + 1) & 1;

        // Skewed access: shift tile boundaries by 1 each timestep
        int skew = t;
        int sx = tx + 1 - skew;
        if (sx >= 1 && sx <= 128) {
            s[nxt][sx] = 0.25f * s[cur][sx-1] + 0.5f * s[cur][sx] + 0.25f * s[cur][sx+1];
        }
        __syncthreads();
    }

    int last = timesteps & 1;
    if (gx < nx) out[gx] = s[last][tx + 1];
}

// Hexagonal tile: 6-neighbor stencil with offset rows
extern "C" __global__ void __launch_bounds__(128)
probe_tile_hexagonal(float *out, const float *in, int nx, int ny) {
    int tx = threadIdx.x % 16, ty = threadIdx.x / 16;
    int bx = blockIdx.x * 16, by = blockIdx.y * 8;
    int gx = bx + tx, gy = by + ty;

    if (gx >= 1 && gx < nx-1 && gy >= 1 && gy < ny-1) {
        // Hex neighbors depend on row parity (even/odd row offset)
        int offset = (gy & 1) ? 1 : -1;
        float center = in[gy * nx + gx];
        float n1 = in[(gy-1) * nx + gx];
        float n2 = in[(gy-1) * nx + gx + offset];
        float n3 = in[gy * nx + gx - 1];
        float n4 = in[gy * nx + gx + 1];
        float n5 = in[(gy+1) * nx + gx];
        float n6 = in[(gy+1) * nx + gx + offset];

        out[gy * nx + gx] = (center + n1 + n2 + n3 + n4 + n5 + n6) / 7.0f;
    }
}
