/*
 * SASS RE Probe: Register-Blocked Tiling Patterns
 * Isolates: Thread coarsening, register tiling, ILP via multi-element ownership
 *
 * Register blocking: each thread processes NxM output elements, keeping
 * all intermediate values in registers. This increases ILP and reduces
 * the ratio of memory ops to compute ops.
 *
 * Patterns from production kernels:
 *   - LBM 2-cell coarsening (kernels_soa.cu: float2, each thread owns 2 cells)
 *   - LBM 4-cell coarsening (float4, each thread owns 4 cells)
 *   - GEMM register tiling (4x4 output tile per thread)
 *   - Reduction with register accumulation (multiple partial sums)
 */

// 1x1 register tile (baseline, no coarsening)
extern "C" __global__ void __launch_bounds__(128)
probe_regtile_1x1(float *out, const float *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    float a = in[i];
    float r = a * a + a;  // Simple compute
    out[i] = r;
}

// 2x1 register tile (2 elements per thread, float2 loads)
extern "C" __global__ void __launch_bounds__(128)
probe_regtile_2x1(float *out, const float *in, int n) {
    int i = (threadIdx.x + blockIdx.x * blockDim.x) * 2;
    if (i + 1 >= n) return;
    float2 a = *reinterpret_cast<const float2*>(&in[i]);
    float r0 = a.x * a.x + a.x;
    float r1 = a.y * a.y + a.y;
    *reinterpret_cast<float2*>(&out[i]) = make_float2(r0, r1);
}

// 4x1 register tile (4 elements per thread, float4 loads)
extern "C" __global__ void __launch_bounds__(128)
probe_regtile_4x1(float *out, const float *in, int n) {
    int i = (threadIdx.x + blockIdx.x * blockDim.x) * 4;
    if (i + 3 >= n) return;
    float4 a = *reinterpret_cast<const float4*>(&in[i]);
    float4 r;
    r.x = a.x * a.x + a.x;
    r.y = a.y * a.y + a.y;
    r.z = a.z * a.z + a.z;
    r.w = a.w * a.w + a.w;
    *reinterpret_cast<float4*>(&out[i]) = r;
}

// 2x2 register tile (4 output elements in 2D, for matrix/stencil)
extern "C" __global__ void __launch_bounds__(128)
probe_regtile_2x2(float *out, const float *A, const float *B,
                   int M, int N, int K) {
    // Each thread computes a 2x2 output tile of C = A * B
    int row = (blockIdx.y * blockDim.y + threadIdx.y) * 2;
    int col = (blockIdx.x * blockDim.x + threadIdx.x) * 2;

    float c00 = 0.0f, c01 = 0.0f, c10 = 0.0f, c11 = 0.0f;

    for (int k = 0; k < K; k++) {
        float a0 = A[row * K + k];
        float a1 = A[(row+1) * K + k];
        float b0 = B[k * N + col];
        float b1 = B[k * N + col + 1];

        c00 = fmaf(a0, b0, c00);
        c01 = fmaf(a0, b1, c01);
        c10 = fmaf(a1, b0, c10);
        c11 = fmaf(a1, b1, c11);
    }

    if (row < M && col < N) {
        out[row * N + col] = c00;
        out[row * N + col + 1] = c01;
        out[(row+1) * N + col] = c10;
        out[(row+1) * N + col + 1] = c11;
    }
}

// 4x4 register tile (16 output elements, maximal ILP)
extern "C" __global__ void __launch_bounds__(64)
probe_regtile_4x4(float *out, const float *A, const float *B,
                   int M, int N, int K) {
    int row = (blockIdx.y * blockDim.y + threadIdx.y) * 4;
    int col = (blockIdx.x * blockDim.x + threadIdx.x) * 4;

    float c[4][4];
    #pragma unroll
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            c[i][j] = 0.0f;

    for (int k = 0; k < K; k++) {
        float a[4], b[4];
        #pragma unroll
        for (int i = 0; i < 4; i++) a[i] = A[(row+i) * K + k];
        #pragma unroll
        for (int j = 0; j < 4; j++) b[j] = B[k * N + col + j];
        #pragma unroll
        for (int i = 0; i < 4; i++)
            #pragma unroll
            for (int j = 0; j < 4; j++)
                c[i][j] = fmaf(a[i], b[j], c[i][j]);
    }

    #pragma unroll
    for (int i = 0; i < 4; i++)
        #pragma unroll
        for (int j = 0; j < 4; j++)
            if (row+i < M && col+j < N)
                out[(row+i) * N + col + j] = c[i][j];
}

// LBM-style 2-cell coarsened with interleaved collision (from kernels_soa.cu)
extern "C" __global__ void __launch_bounds__(128)
probe_regtile_lbm_2cell(float *f_out, const float *f_in,
                         int n_cells) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    int cell_a = tid * 2;
    int cell_b = tid * 2 + 1;
    if (cell_b >= n_cells) return;

    // Load 19 distributions for 2 cells (38 registers)
    float fa[19], fb[19];
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        fa[d] = f_in[d * n_cells + cell_a];
        fb[d] = f_in[d * n_cells + cell_b];
    }

    // Interleaved collision (ILP: fa and fb chains are independent)
    float rho_a = 0.0f, rho_b = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        rho_a += fa[d];
        rho_b += fb[d];
    }

    float inv_tau = 1.0f / 0.6f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        float feq_a = rho_a / 19.0f;
        float feq_b = rho_b / 19.0f;
        fa[d] -= (fa[d] - feq_a) * inv_tau;
        fb[d] -= (fb[d] - feq_b) * inv_tau;
    }

    // Store
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        f_out[d * n_cells + cell_a] = fa[d];
        f_out[d * n_cells + cell_b] = fb[d];
    }
}

// Warp-tiled reduction: each warp reduces a chunk cooperatively
extern "C" __global__ void __launch_bounds__(256)
probe_regtile_warp_reduce(float *out, const float *in, int n) {
    __shared__ float warp_sums[8];  // 256/32 = 8 warps
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    int warp_id = threadIdx.x / 32;
    int lane = threadIdx.x % 32;

    // Each thread accumulates 4 elements (register blocking)
    float acc = 0.0f;
    int base = tid * 4;
    if (base + 3 < n) {
        float4 v = *reinterpret_cast<const float4*>(&in[base]);
        acc = v.x + v.y + v.z + v.w;
    }

    // Warp-level reduction
    #pragma unroll
    for (int offset = 16; offset > 0; offset /= 2)
        acc += __shfl_xor_sync(0xFFFFFFFF, acc, offset);

    if (lane == 0) warp_sums[warp_id] = acc;
    __syncthreads();

    // Final reduction across warps (first warp only)
    if (warp_id == 0 && lane < 8) {
        float val = warp_sums[lane];
        for (int offset = 4; offset > 0; offset /= 2)
            val += __shfl_xor_sync(0xFF, val, offset);
        if (lane == 0) atomicAdd(out, val);
    }
}
