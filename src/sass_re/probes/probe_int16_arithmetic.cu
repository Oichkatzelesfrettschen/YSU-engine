/*
 * SASS RE Probe: INT16 (Short) Arithmetic and Vectorized Operations
 * Isolates: I2F.S16, short2 vectorized loads, INT16 multiply, DP2A (if exists)
 *
 * Ada SM 8.9 has NO native 16-bit integer ALU instructions.
 * INT16 values are widened to INT32 for all arithmetic, then narrowed back.
 * The cost is: I2F.S16 (widen) + INT32 op + F2I.S16 (narrow).
 *
 * DP2A (2-element dot product) may exist for INT16 pairs -- this probe tests it.
 *
 * Key SASS to look for:
 *   I2F.S16     -- sign-extend short to int (or direct to float)
 *   LDG.E.U16   -- 16-bit load
 *   LDG.E.64    -- vectorized short4 load (4 shorts = 64 bits)
 *   IMAD.IADD   -- widened INT16 arithmetic
 */

// INT16 load and arithmetic
extern "C" __global__ void __launch_bounds__(128)
probe_int16_arith(int *out, const short *a, const short *b, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    // Load short, widen to int, arithmetic, narrow back
    int va = (int)a[i];
    int vb = (int)b[i];
    int sum = va + vb;
    int prod = va * vb;
    out[i] = sum + prod;
}

// INT16 vectorized: short2 (32-bit) and short4 (64-bit) loads
extern "C" __global__ void __launch_bounds__(128)
probe_int16_vectorized(int *out, const short2 *a2, const short4 *a4, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    short2 v2 = a2[i];  // LDG.E (32-bit: 2 shorts)
    short4 v4 = a4[i];  // LDG.E.64 (64-bit: 4 shorts)
    out[i] = (int)v2.x + (int)v2.y + (int)v4.x + (int)v4.y + (int)v4.z + (int)v4.w;
}

// INT16 DIST_SCALE pattern (from kernels_int16.cu LBM)
extern "C" __global__ void __launch_bounds__(128)
probe_int16_dist_scale(float *out, const short *dist, int n_cells) {
    int cell = threadIdx.x + blockIdx.x * blockDim.x;
    if (cell >= n_cells) return;
    const float INV_SCALE = 1.0f / 16384.0f;
    float rho = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        rho += (float)dist[d * n_cells + cell] * INV_SCALE;
    }
    out[cell] = rho;
}
