/*
 * SASS RE Probe: Memory Scope and Prefetch Operations
 * Isolates: LDG.E.SYS, STG.E.SYS, PREFETCH, MEMBAR.SYS
 *
 * Memory scope controls the visibility of loads/stores:
 *   .CTA   -- visible within the thread block (default for shared mem)
 *   .GPU   -- visible within the GPU (default for global mem)
 *   .SYS   -- visible across GPUs and to host CPU (system scope)
 *
 * System-scope operations are needed for:
 *   - Multi-GPU communication (peer-to-peer memory access)
 *   - Host-device synchronization (mapped/unified memory)
 *   - CUDA IPC (inter-process communication)
 *
 * PREFETCH is an explicit hint to bring data into cache before use.
 * Ada Lovelace has hardware prefetchers, but explicit prefetch may
 * help for irregular access patterns.
 *
 * Key SASS:
 *   LDG.E.SYS    -- system-scope global load
 *   STG.E.SYS    -- system-scope global store
 *   MEMBAR.SYS   -- system-scope memory fence
 *   MEMBAR.GPU   -- GPU-scope memory fence (standard __threadfence)
 *   PREFETCH.GLOBAL.L1 -- prefetch to L1
 *   PREFETCH.GLOBAL.L2 -- prefetch to L2
 */

// System-scope load/store (cross-GPU coherent)
extern "C" __global__ void __launch_bounds__(32)
probe_sys_scope(volatile int *out, volatile int *in) {
    int i = threadIdx.x;

    // System-scope load via volatile + __threadfence_system
    int val = in[i];
    __threadfence_system();  // MEMBAR.SYS

    // System-scope store
    out[i] = val + 1;
    __threadfence_system();  // MEMBAR.SYS
}

// GPU-scope vs system-scope fence comparison
extern "C" __global__ void __launch_bounds__(32)
probe_fence_scopes(volatile int *flag, volatile int *data) {
    int i = threadIdx.x;

    if (i == 0) {
        data[0] = 42;

        // GPU-scope fence (standard)
        __threadfence();         // MEMBAR.GPU

        // System-scope fence (cross-GPU/host visible)
        __threadfence_system();  // MEMBAR.SYS

        // Block-scope fence
        __threadfence_block();   // MEMBAR.CTA

        flag[0] = 1;
    }
}

// Software prefetch via inline PTX
extern "C" __global__ void __launch_bounds__(128)
probe_prefetch(float *out, const float *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    // Prefetch next cache line while processing current
    if (i + 128 < n) {
        // PREFETCH.GLOBAL.L1: bring data into L1
        asm volatile("prefetch.global.L1 [%0];" :: "l"(&in[i + 128]));
    }
    if (i + 256 < n) {
        // PREFETCH.GLOBAL.L2: bring data into L2 only
        asm volatile("prefetch.global.L2 [%0];" :: "l"(&in[i + 256]));
    }

    // Process current element
    out[i] = in[i] * 2.0f + 1.0f;
}

// Prefetch with stride (simulates D3Q19 pull-scheme prefetch)
extern "C" __global__ void __launch_bounds__(128)
probe_prefetch_strided(float *out, const float *in, int n_cells) {
    int cell = threadIdx.x + blockIdx.x * blockDim.x;
    if (cell >= n_cells) return;

    // Prefetch all 19 direction buffers for the next block of cells
    int next_cell = cell + blockDim.x;
    if (next_cell < n_cells) {
        #pragma unroll
        for (int d = 0; d < 19; d++) {
            asm volatile("prefetch.global.L2 [%0];" :: "l"(&in[d * n_cells + next_cell]));
        }
    }

    // Process current cell: load 19 distributions, sum
    float rho = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        rho += in[d * n_cells + cell];
    }
    out[cell] = rho;
}
