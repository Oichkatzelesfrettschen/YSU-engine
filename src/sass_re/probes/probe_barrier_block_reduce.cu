/*
 * SASS RE Probe: Barrier in Block-Level Reduction Patterns
 * Isolates: __syncthreads at each tree reduction level, partial warps
 *
 * Block reduction is the canonical barrier usage pattern.
 * At each level, half the threads drop out. This creates:
 *   Level 0: 256 threads active, BAR.SYNC 256
 *   Level 1: 128 threads active (but BAR.SYNC still syncs 256?)
 *   ...
 *   Level 7: 2 threads active
 *   Level 8: warp-level (no barrier needed)
 */

// Tree reduction with __syncthreads at every level
extern "C" __global__ void __launch_bounds__(256)
probe_bar_tree_reduce(float *out, const float *in) {
    __shared__ float s[256];
    int tid = threadIdx.x;
    s[tid] = in[tid + blockIdx.x * 256];
    __syncthreads();

    // 8 levels of tree reduction with barrier at each
    for (int stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            s[tid] += s[tid + stride];
        }
        __syncthreads();  // BAR.SYNC at each level
    }
    if (tid == 0) out[blockIdx.x] = s[0];
}

// Optimized: switch to warp-level at stride <= 32 (no barrier needed)
extern "C" __global__ void __launch_bounds__(256)
probe_bar_tree_reduce_warp_opt(float *out, const float *in) {
    __shared__ float s[256];
    int tid = threadIdx.x;
    s[tid] = in[tid + blockIdx.x * 256];
    __syncthreads();

    // Block-level reduction (barrier needed)
    for (int stride = 128; stride > 32; stride >>= 1) {
        if (tid < stride) s[tid] += s[tid + stride];
        __syncthreads();
    }

    // Warp-level reduction (no barrier, use volatile or __syncwarp)
    if (tid < 32) {
        volatile float *vs = s;
        vs[tid] += vs[tid + 32];
        __syncwarp();
        vs[tid] += vs[tid + 16];
        __syncwarp();
        vs[tid] += vs[tid + 8];
        __syncwarp();
        vs[tid] += vs[tid + 4];
        __syncwarp();
        vs[tid] += vs[tid + 2];
        __syncwarp();
        vs[tid] += vs[tid + 1];
    }
    if (tid == 0) out[blockIdx.x] = s[0];
}

// Segmented reduction: multiple barriers for independent segments
extern "C" __global__ void __launch_bounds__(256)
probe_bar_segmented_reduce(float *out, const float *in, int seg_size) {
    __shared__ float s[256];
    int tid = threadIdx.x;
    int seg = tid / seg_size;
    int seg_tid = tid % seg_size;

    s[tid] = in[tid + blockIdx.x * 256];
    __syncthreads();

    // Reduce within each segment (all segments reduce in parallel)
    for (int stride = seg_size / 2; stride > 0; stride >>= 1) {
        if (seg_tid < stride) {
            s[seg * seg_size + seg_tid] += s[seg * seg_size + seg_tid + stride];
        }
        __syncthreads();
    }

    if (seg_tid == 0)
        out[blockIdx.x * (256 / seg_size) + seg] = s[seg * seg_size];
}
