/*
 * SASS RE Probe: Memory Fence (MEMBAR) Variants
 * Isolates: All scope/ordering combinations of memory barriers
 *
 * Ada MEMBAR instruction variants by scope:
 *   .CTA  -- block-scope (cheapest, visible within thread block)
 *   .GPU  -- device-scope (visible to all SMs)
 *   .SYS  -- system-scope (visible to all GPUs + host CPU)
 *
 * And by ordering:
 *   .GL   -- global (load/store ordering for global memory)
 *   .SC   -- sequential consistency (strictest ordering)
 *   .VC   -- virtual channel (used in debug builds)
 */

// CTA-scope fence (__threadfence_block)
extern "C" __global__ void __launch_bounds__(128)
probe_membar_cta(volatile int *flag, volatile int *data) {
    int tid = threadIdx.x;
    if (tid == 0) {
        data[0] = 42;
        __threadfence_block();  // MEMBAR.SC.CTA
        flag[0] = 1;
    }
    __syncthreads();
    if (tid == 1) {
        while (flag[0] == 0);  // Spin until flag set
        data[1] = data[0];     // Should see 42
    }
}

// GPU-scope fence (__threadfence)
extern "C" __global__ void __launch_bounds__(128)
probe_membar_gpu(volatile int *flag, volatile int *data) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        data[0] = 42;
        __threadfence();  // MEMBAR.SC.GPU (or MEMBAR.ALL.GPU)
        flag[0] = 1;
    }
}

// System-scope fence (__threadfence_system)
extern "C" __global__ void __launch_bounds__(128)
probe_membar_sys(volatile int *flag, volatile int *data) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        data[0] = 42;
        __threadfence_system();  // MEMBAR.SC.SYS
        flag[0] = 1;
    }
}

// All three fences in sequence (compare SASS for each)
extern "C" __global__ void __launch_bounds__(128)
probe_membar_all_scopes(volatile int *data) {
    int tid = threadIdx.x;
    data[tid] = tid;
    __threadfence_block();   // MEMBAR.SC.CTA or MEMBAR.GL.CTA
    data[tid + 128] = tid;
    __threadfence();         // MEMBAR.SC.GPU or MEMBAR.ALL.GPU
    data[tid + 256] = tid;
    __threadfence_system();  // MEMBAR.SC.SYS
    data[tid + 384] = tid;
}

// Fence + atomic pattern (common in lock-free algorithms)
extern "C" __global__ void __launch_bounds__(128)
probe_membar_atomic_release(int *lock, int *data) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    // Acquire: atomicCAS on lock
    if (tid == 0) {
        while (atomicCAS(lock, 0, 1) != 0);  // Spin acquire
        // Critical section
        data[0] = data[0] + 1;
        __threadfence();  // Ensure data write visible before lock release
        atomicExch(lock, 0);  // Release
    }
}

// Fence latency chain (for measuring fence overhead)
extern "C" __global__ void __launch_bounds__(32)
probe_membar_cta_chain(volatile int *sink, volatile long long *out) {
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll
    for (int i = 0; i < 512; i++)
        __threadfence_block();
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    sink[0] = (int)(t1 & 0xFF);
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 512; }
}
