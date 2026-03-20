/*
 * SASS RE Probe: Scatter/Gather Tiling Patterns
 * Isolates: Indirect addressing, permuted access, gather-compute-scatter
 *
 * These patterns use index arrays for non-contiguous memory access,
 * generating different LDG/STG addressing modes and IMAD chains.
 */

// Gather: load from scattered locations, process, store contiguous
extern "C" __global__ void __launch_bounds__(128)
probe_tile_gather(float *out, const float *in, const int *indices, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    int idx = indices[i];  // Indirect load (likely cache-miss pattern)
    out[i] = in[idx] * 2.0f + 1.0f;
}

// Scatter: load contiguous, process, store to scattered locations
extern "C" __global__ void __launch_bounds__(128)
probe_tile_scatter(float *out, const float *in, const int *indices, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    float val = in[i] * 2.0f + 1.0f;
    int idx = indices[i];
    out[idx] = val;  // Scattered store (non-coalesced)
}

// Gather-compute-scatter: full indirect pipeline
extern "C" __global__ void __launch_bounds__(128)
probe_tile_gather_scatter(float *out, const float *in,
                          const int *gather_idx, const int *scatter_idx, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    float val = in[gather_idx[i]];      // Gather
    val = val * val + val;               // Compute
    out[scatter_idx[i]] = val;           // Scatter
}

// Tiled gather with shared memory staging
extern "C" __global__ void __launch_bounds__(128)
probe_tile_gather_staged(float *out, const float *in,
                          const int *indices, int n) {
    __shared__ float s[128];
    int tid = threadIdx.x;
    int base = blockIdx.x * 128;
    if (base + tid < n) {
        s[tid] = in[indices[base + tid]];  // Gather into smem
    }
    __syncthreads();
    // Process in smem (neighbor access is now coalesced)
    if (base + tid < n) {
        float left = (tid > 0) ? s[tid-1] : s[tid];
        float right = (tid < 127) ? s[tid+1] : s[tid];
        out[base + tid] = 0.25f * left + 0.5f * s[tid] + 0.25f * right;
    }
}

// Bit-reversal permutation (FFT pattern)
extern "C" __global__ void __launch_bounds__(256)
probe_tile_bitrev_permute(float *out, const float *in, int log_n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int n = 1 << log_n;
    if (i >= n) return;
    // Bit-reverse index
    int rev = __brev(i) >> (32 - log_n);
    out[rev] = in[i];  // Scatter via bit-reversal
}

// AoS-to-SoA transpose (struct-of-arrays conversion)
extern "C" __global__ void __launch_bounds__(256)
probe_tile_aos_to_soa(float *soa_out, const float *aos_in,
                       int n_elements, int n_fields) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if (tid >= n_elements) return;
    // AoS: in[element * n_fields + field]
    // SoA: out[field * n_elements + element]
    for (int f = 0; f < n_fields; f++) {
        soa_out[f * n_elements + tid] = aos_in[tid * n_fields + f];
    }
}

// SoA-to-AoS transpose
extern "C" __global__ void __launch_bounds__(256)
probe_tile_soa_to_aos(float *aos_out, const float *soa_in,
                       int n_elements, int n_fields) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if (tid >= n_elements) return;
    for (int f = 0; f < n_fields; f++) {
        aos_out[tid * n_fields + f] = soa_in[f * n_elements + tid];
    }
}
