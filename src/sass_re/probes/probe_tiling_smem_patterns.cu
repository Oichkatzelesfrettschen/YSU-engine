/*
 * SASS RE Probe: Shared Memory Tiling Layout Patterns
 * Isolates: Row-major vs column-major vs swizzled smem, bank conflict avoidance
 *
 * Different shared memory layouts affect bank conflicts and throughput.
 * This probe tests: row-major, column-major (+1 padding), XOR-swizzled,
 * and triangular layouts used in various GPU algorithms.
 */

#define TILE 32

// Row-major smem (standard, potential bank conflicts on column access)
extern "C" __global__ void __launch_bounds__(256)
probe_smem_row_major(float *out, const float *in, int n) {
    __shared__ float tile[TILE][TILE];
    int tx = threadIdx.x % TILE, ty = threadIdx.x / TILE;
    int gx = blockIdx.x * TILE + tx, gy = blockIdx.y * TILE + ty;

    // Load row-major (coalesced global, stride-1 smem -> no conflict)
    if (gx < n && gy < n) tile[ty][tx] = in[gy * n + gx];
    __syncthreads();

    // Read column-major (stride-32 smem -> 32-way bank conflict!)
    if (gx < n && gy < n) out[gy * n + gx] = tile[tx][ty];
}

// Padded smem: [TILE][TILE+1] avoids bank conflicts on column access
extern "C" __global__ void __launch_bounds__(256)
probe_smem_padded(float *out, const float *in, int n) {
    __shared__ float tile[TILE][TILE + 1];  // +1 padding
    int tx = threadIdx.x % TILE, ty = threadIdx.x / TILE;
    int gx = blockIdx.x * TILE + tx, gy = blockIdx.y * TILE + ty;

    if (gx < n && gy < n) tile[ty][tx] = in[gy * n + gx];
    __syncthreads();

    // Column access now conflict-free (stride 33, coprime with 32)
    if (gx < n && gy < n) out[gy * n + gx] = tile[tx][ty];
}

// XOR-swizzled smem: tile[y][x ^ y] maps to unique banks
extern "C" __global__ void __launch_bounds__(256)
probe_smem_xor_swizzle(float *out, const float *in, int n) {
    __shared__ float tile[TILE][TILE];
    int tx = threadIdx.x % TILE, ty = threadIdx.x / TILE;
    int gx = blockIdx.x * TILE + tx, gy = blockIdx.y * TILE + ty;

    // Store with XOR swizzle
    if (gx < n && gy < n) tile[ty][tx ^ ty] = in[gy * n + gx];
    __syncthreads();

    // Read with XOR unswizzle (conflict-free for both row and column)
    if (gx < n && gy < n) out[gy * n + gx] = tile[tx][ty ^ tx];
}

// Matrix transpose via shared memory (classic bank conflict pattern)
extern "C" __global__ void __launch_bounds__(256)
probe_smem_transpose(float *out, const float *in, int nx, int ny) {
    __shared__ float tile[TILE][TILE + 1];  // Padded for conflict-free transpose
    int bx = blockIdx.x * TILE, by = blockIdx.y * TILE;
    int tx = threadIdx.x % TILE, ty = threadIdx.x / TILE;

    // Read from input (row-major, coalesced)
    int gx = bx + tx, gy = by + ty;
    if (gx < nx && gy < ny) tile[ty][tx] = in[gy * nx + gx];
    __syncthreads();

    // Write transposed (swap x/y tile position, column read from smem)
    gx = by + tx;  // Note: swapped bx/by for output
    gy = bx + ty;
    if (gx < ny && gy < nx) out[gy * ny + gx] = tile[tx][ty];
}

// Sliding window tile (for 1D convolution / scan patterns)
extern "C" __global__ void __launch_bounds__(128)
probe_smem_sliding_window(float *out, const float *in, int n, int radius) {
    extern __shared__ float window[];
    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + tid;

    // Load tile + halo into shared memory
    int smem_size = blockDim.x + 2 * radius;
    for (int i = tid; i < smem_size; i += blockDim.x) {
        int gi = blockIdx.x * blockDim.x + i - radius;
        window[i] = (gi >= 0 && gi < n) ? in[gi] : 0.0f;
    }
    __syncthreads();

    if (gid < n) {
        float sum = 0.0f;
        for (int r = -radius; r <= radius; r++)
            sum += window[tid + radius + r];
        out[gid] = sum / (float)(2 * radius + 1);
    }
}

// Multi-stage tiled pipeline: load tile N+1 while computing tile N
extern "C" __global__ void __launch_bounds__(128)
probe_smem_pipeline_tile(float *out, const float *in, int n_tiles, int tile_size) {
    extern __shared__ float smem[];
    float *buf0 = smem;
    float *buf1 = smem + tile_size;
    int tid = threadIdx.x;

    // Load first tile
    if (tid < tile_size)
        buf0[tid] = in[tid];
    __syncthreads();

    for (int t = 1; t < n_tiles; t++) {
        float *cur = (t & 1) ? buf1 : buf0;
        float *nxt = (t & 1) ? buf0 : buf1;

        // Load next tile
        if (tid < tile_size)
            nxt[tid] = in[t * tile_size + tid];

        // Compute on current tile
        if (tid < tile_size) {
            float val = cur[tid];
            out[(t-1) * tile_size + tid] = val * val + val;
        }
        __syncthreads();
    }

    // Process last tile
    float *last = ((n_tiles-1) & 1) ? buf1 : buf0;
    if (tid < tile_size)
        out[(n_tiles-1) * tile_size + tid] = last[tid] * last[tid] + last[tid];
}
