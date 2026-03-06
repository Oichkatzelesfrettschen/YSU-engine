/*
 * SASS RE Probe: Special Registers
 * Isolates: S2R (system register read), CS2R, NANOSLEEP
 *
 * S2R reads special registers like:
 *   SR_TID.X/Y/Z    -- threadIdx
 *   SR_CTAID.X/Y/Z  -- blockIdx
 *   SR_NTID.X/Y/Z   -- blockDim
 *   SR_CLOCK_LO/HI  -- cycle counter
 *   SR_GLOBALTIMER_LO/HI -- nanosecond timer
 *   SR_LANEID        -- warp lane ID
 *   SR_WARPID        -- warp ID within block
 *   SR_SMID          -- SM ID
 *
 * These are critical for microbenchmarking: clock() compiles to S2R SR_CLOCK_LO.
 */

// Read all common special registers
extern "C" __global__ void __launch_bounds__(32)
probe_special_regs(int *out) {
    int i = threadIdx.x;

    // These all compile to S2R instructions:
    int tid_x = threadIdx.x;          // S2R Rd, SR_TID.X
    int tid_y = threadIdx.y;          // S2R Rd, SR_TID.Y
    int tid_z = threadIdx.z;          // S2R Rd, SR_TID.Z
    int bid_x = blockIdx.x;           // S2R Rd, SR_CTAID.X
    int bid_y = blockIdx.y;           // S2R Rd, SR_CTAID.Y
    int ndim_x = blockDim.x;          // S2R Rd, SR_NTID.X

    // Clock counter -- used for microbenchmarking
    int clk = clock();                 // S2R Rd, SR_CLOCK_LO

    // Global timer (nanoseconds since GPU reset)
    long long gtimer = clock64();      // CS2R Rd, SR_CLOCK64

    // Lane-level identification
    unsigned lane = 0;
    asm volatile("mov.u32 %0, %%laneid;" : "=r"(lane));    // S2R Rd, SR_LANEID
    unsigned warpid = 0;
    asm volatile("mov.u32 %0, %%warpid;" : "=r"(warpid));  // S2R Rd, SR_WARPID
    unsigned smid = 0;
    asm volatile("mov.u32 %0, %%smid;" : "=r"(smid));      // S2R Rd, SR_SMID

    out[i] = tid_x + tid_y + tid_z + bid_x + bid_y + ndim_x
           + clk + (int)(gtimer & 0xFFFFFFFF) + lane + warpid + smid;
}

// Clock register precision test
// How many cycles does S2R SR_CLOCK_LO take? Read it back-to-back.
extern "C" __global__ void __launch_bounds__(32)
probe_clock_precision(long long *out) {
    int i = threadIdx.x;
    int c0, c1, c2, c3, c4, c5, c6, c7;

    // Barrier to ensure all warps start together
    __syncthreads();

    // Back-to-back clock reads -- the difference between consecutive
    // reads tells you the S2R latency + any stalls
    c0 = clock();
    c1 = clock();
    c2 = clock();
    c3 = clock();
    c4 = clock();
    c5 = clock();
    c6 = clock();
    c7 = clock();

    // Store deltas
    out[i * 4]     = (long long)(c1 - c0);
    out[i * 4 + 1] = (long long)(c3 - c2);
    out[i * 4 + 2] = (long long)(c5 - c4);
    out[i * 4 + 3] = (long long)(c7 - c6);
}
