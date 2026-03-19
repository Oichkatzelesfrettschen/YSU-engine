/*
 * SASS RE Probe: Warp Leader Election and Active Mask Query
 * Isolates: ELECT, ACTIVEMASK, WARPSYNC
 *
 * ELECT selects a single lane from the active mask as the "leader" for
 * warp-level operations (e.g., one thread does the atomicAdd after a
 * ballot+popc reduction).
 *
 * ACTIVEMASK queries which threads in the warp are currently active.
 * This is critical for handling divergent control flow.
 *
 * WARPSYNC forces all threads in a warp to converge (distinct from
 * __syncwarp which is the CUDA intrinsic).
 *
 * Key SASS:
 *   ELECT.SYNC   -- elect leader from active mask
 *   VOTE.ANY     -- used to implement __activemask() in some cases
 *   WARPSYNC     -- warp-level synchronization barrier
 */

// Leader election: one thread per warp does the work
extern "C" __global__ void __launch_bounds__(128)
probe_warp_elect(int *out, const int *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    int val = in[i];

    // Warp-level sum via ballot+popc
    unsigned mask = __ballot_sync(0xFFFFFFFF, val > 0);
    int count = __popc(mask);

    // Only the "first" active lane does the atomic update
    // __ffs(mask) returns position of first set bit (1-indexed)
    int leader = __ffs(mask) - 1;
    if ((threadIdx.x & 31) == leader) {
        atomicAdd(out, count);
    }
}

// Active mask query in divergent context
extern "C" __global__ void __launch_bounds__(32)
probe_activemask(unsigned *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    unsigned full_mask = __activemask();  // Should be 0xFFFFFFFF (all active)
    out[i] = full_mask;

    // Diverge: only even threads
    if (i % 2 == 0) {
        unsigned half_mask = __activemask();  // Should be 0x55555555
        out[i + 32] = half_mask;
    }

    // Diverge: only first 8 threads
    if (i < 8) {
        unsigned eighth_mask = __activemask();  // Should be 0x000000FF
        out[i + 64] = eighth_mask;
    }

    // Single thread
    if (i == 0) {
        unsigned single_mask = __activemask();  // Should be 0x00000001
        out[96] = single_mask;
    }
}

// Warp synchronize after divergent computation
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync(float *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    __shared__ float smem[32];

    // Divergent write
    if (i % 2 == 0) {
        smem[i] = val * 2.0f;
    } else {
        smem[i] = val * 3.0f;
    }

    // WARPSYNC: ensure all threads have written before reading
    __syncwarp(0xFFFFFFFF);

    // Cross-lane read (requires all writes to be visible)
    float neighbor = smem[i ^ 1];
    out[i] = val + neighbor;
}

// Warp sync with partial mask (only active subset synchronizes)
extern "C" __global__ void __launch_bounds__(32)
probe_warpsync_partial(float *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    __shared__ float smem[32];
    smem[i] = val;

    // Only even threads synchronize with each other
    if (i % 2 == 0) {
        __syncwarp(0x55555555);  // Only even lanes
        float partner = smem[(i + 2) % 32];
        out[i] = val + partner;
    } else {
        __syncwarp(0xAAAAAAAA);  // Only odd lanes
        float partner = smem[(i + 2) % 32];
        out[i] = val - partner;
    }
}
