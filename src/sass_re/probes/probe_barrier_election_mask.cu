/*
 * SASS RE Probe: Barrier + Election + Active Mask Interactions
 * Isolates: How barriers interact with warp divergence, elections, masks
 */

// Barrier after warp-level election (only elected thread does work)
extern "C" __global__ void __launch_bounds__(128)
probe_barrier_after_elect(int *out, const int *in) {
    __shared__ int leader_result;
    int tid = threadIdx.x;
    int val = in[tid + blockIdx.x * 128];

    // Warp reduction
    unsigned mask = __ballot_sync(0xFFFFFFFF, val > 0);
    int count = __popc(mask);

    // Elect leader (first set bit)
    int leader = __ffs(mask) - 1;
    if ((tid & 31) == leader) {
        leader_result = count;
    }
    __syncthreads();  // Barrier after divergent election
    out[tid + blockIdx.x * 128] = leader_result + val;
}

// Active mask changes through barrier (divergent threads rejoin)
extern "C" __global__ void __launch_bounds__(128)
probe_barrier_mask_change(float *out, const float *in) {
    __shared__ float s[128];
    int tid = threadIdx.x;
    float val = in[tid + blockIdx.x * 128];

    // Only even threads write to smem
    if (tid % 2 == 0) {
        s[tid] = val * 2.0f;
    }
    // Barrier reunites all threads (active mask returns to full)
    __syncthreads();

    // All threads can now read
    float result = s[tid & ~1];  // Read from even neighbor
    out[tid + blockIdx.x * 128] = result;
}

// Spin-wait barrier emulation (generates NANOSLEEP/YIELD + atomics)
extern "C" __global__ void __launch_bounds__(128)
probe_barrier_spinwait(volatile int *flag, float *out, const float *in) {
    int tid = threadIdx.x + blockIdx.x * 128;
    float val = in[tid];

    if (threadIdx.x == 0) {
        // Producer: write data then set flag
        out[tid] = val * 2.0f;
        __threadfence();
        atomicExch((int*)&flag[blockIdx.x], 1);
    } else if (threadIdx.x == 1) {
        // Consumer: spin-wait on flag
        while (atomicAdd((int*)&flag[blockIdx.x], 0) == 0) {
            __nanosleep(32);  // NANOSLEEP in spin loop
        }
        __threadfence();
        out[tid] = out[blockIdx.x * 128] + val;
    }
}
