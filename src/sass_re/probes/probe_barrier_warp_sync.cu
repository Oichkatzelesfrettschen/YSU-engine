/*
 * SASS RE Probe: Warp-Level Synchronization Variants
 * Isolates: __syncwarp with various masks, WARPSYNC variants
 */

// Full warp sync (all 32 lanes)
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync_full(float *out, const float *in) {
    __shared__ float s[32];
    s[threadIdx.x] = in[threadIdx.x];
    __syncwarp(0xFFFFFFFF);
    out[threadIdx.x] = s[31 - threadIdx.x];
}

// Half-warp sync (even lanes only)
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync_even(float *out, const float *in) {
    __shared__ float s[32];
    s[threadIdx.x] = in[threadIdx.x];
    if (threadIdx.x % 2 == 0) {
        __syncwarp(0x55555555);  // Even lanes only
        out[threadIdx.x] = s[threadIdx.x] + s[(threadIdx.x + 2) % 32];
    } else {
        __syncwarp(0xAAAAAAAA);  // Odd lanes only
        out[threadIdx.x] = s[threadIdx.x] - s[(threadIdx.x + 2) % 32];
    }
}

// Quarter-warp sync (groups of 8)
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync_quarter(float *out, const float *in) {
    __shared__ float s[32];
    int tid = threadIdx.x;
    s[tid] = in[tid];
    unsigned mask = 0xFFu << ((tid / 8) * 8);  // 8-lane groups
    __syncwarp(mask);
    int base = (tid / 8) * 8;
    float sum = 0.0f;
    for (int j = 0; j < 8; j++) sum += s[base + j];
    out[tid] = sum;
}

// Cascaded warp sync (sync within increasingly large groups)
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync_cascade(float *out, const float *in) {
    int tid = threadIdx.x;
    float val = in[tid];
    // Sync pairs
    __syncwarp(0x3u << ((tid / 2) * 2));
    val += __shfl_xor_sync(0x3u << ((tid/2)*2), val, 1);
    // Sync quads
    __syncwarp(0xFu << ((tid / 4) * 4));
    val += __shfl_xor_sync(0xFu << ((tid/4)*4), val, 2);
    // Sync octets
    __syncwarp(0xFFu << ((tid / 8) * 8));
    val += __shfl_xor_sync(0xFFu << ((tid/8)*8), val, 4);
    // Full warp
    __syncwarp(0xFFFFFFFF);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 8);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 16);
    out[tid] = val;
}
