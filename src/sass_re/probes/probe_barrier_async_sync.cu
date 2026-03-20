/*
 * SASS RE Probe: Async Copy Barrier Variants
 * Isolates: cp.async commit/wait barrier interactions with LDGSTS/LDGDEPBAR
 *
 * cp.async uses a separate barrier mechanism from __syncthreads:
 *   __pipeline_commit()    -> LDGDEPBAR or specialized barrier
 *   __pipeline_wait_prior(N) -> wait until N groups outstanding
 *   __pipeline_wait_all()  -> wait for all outstanding groups
 */

#include <cuda_pipeline.h>

// Single group commit/wait
extern "C" __global__ void __launch_bounds__(128)
probe_async_barrier_single(float *out, const float *in) {
    __shared__ float s[128];
    int tid = threadIdx.x;
    __pipeline_memcpy_async(&s[tid], &in[tid + blockIdx.x * 128], sizeof(float));
    __pipeline_commit();
    __pipeline_wait_prior(0);  // Wait for all (0 outstanding)
    __syncthreads();
    out[tid + blockIdx.x * 128] = s[127 - tid];
}

// Multi-group pipeline (2 outstanding groups)
extern "C" __global__ void __launch_bounds__(128)
probe_async_barrier_multi(float *out, const float *in, int n_tiles) {
    __shared__ float s[2][128];
    int tid = threadIdx.x;

    // Issue group 0
    __pipeline_memcpy_async(&s[0][tid], &in[tid], sizeof(float));
    __pipeline_commit();

    // Issue group 1
    __pipeline_memcpy_async(&s[1][tid], &in[128 + tid], sizeof(float));
    __pipeline_commit();

    // Wait for group 0 only (1 still outstanding)
    __pipeline_wait_prior(1);
    __syncthreads();
    out[tid] = s[0][tid] * 2.0f;
    __syncthreads();

    // Wait for group 1
    __pipeline_wait_prior(0);
    __syncthreads();
    out[128 + tid] = s[1][tid] * 2.0f;
}

// Deep pipeline (4 outstanding groups)
extern "C" __global__ void __launch_bounds__(128)
probe_async_barrier_deep(float *out, const float *in, int n_tiles) {
    __shared__ float s[4][128];
    int tid = threadIdx.x;

    // Issue 4 groups
    for (int g = 0; g < 4; g++) {
        __pipeline_memcpy_async(&s[g][tid], &in[g * 128 + tid], sizeof(float));
        __pipeline_commit();
    }

    // Process in order: wait for each as needed
    for (int g = 0; g < 4; g++) {
        __pipeline_wait_prior(3 - g);  // Wait for oldest group
        __syncthreads();
        out[g * 128 + tid] = s[g][tid] * 2.0f;
        __syncthreads();
    }
}
