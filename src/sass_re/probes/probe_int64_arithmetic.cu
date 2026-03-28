/*
 * SASS RE Probe: 64-bit Integer Arithmetic
 * Isolates: IMAD.WIDE, 64-bit shifts, 64-bit compare, __umul64hi
 *
 * Ada has NO native 64-bit integer ALU. All 64-bit int operations
 * decompose into 32-bit instruction sequences:
 *   64-bit add: IADD3 (lo) + IADD3.X (hi, with carry)
 *   64-bit mul: IMAD.WIDE (32x32->64) partial products
 *   64-bit shift: SHF pair (funnel shift across 2 registers)
 *   64-bit compare: cascaded ISETP on hi then lo
 *
 * Key SASS:
 *   IMAD.WIDE    -- 32x32->64 multiply (part of 64-bit multiply)
 *   IMAD.WIDE.U32 -- unsigned variant
 *   IADD3.X      -- carry-propagating add (high word)
 *   SHF.L.U64    -- 64-bit left funnel shift (if exists)
 */

// 64-bit add chain
extern "C" __global__ void __launch_bounds__(32)
probe_int64_add(long long *out, const long long *in) {
    int i = threadIdx.x;
    long long acc = in[i];
    #pragma unroll 1
    for (int j = 0; j < 256; j++)
        acc += 1LL;
    out[i] = acc;
}

// 64-bit multiply chain
extern "C" __global__ void __launch_bounds__(32)
probe_int64_mul(long long *out, const long long *a, const long long *b) {
    int i = threadIdx.x;
    long long va = a[i], vb = b[i];
    long long acc = 0;
    #pragma unroll 1
    for (int j = 0; j < 128; j++)
        acc += va * vb;
    out[i] = acc;
}

// 64-bit shift chain
extern "C" __global__ void __launch_bounds__(32)
probe_int64_shift(unsigned long long *out, const unsigned long long *in) {
    int i = threadIdx.x;
    unsigned long long val = in[i];
    #pragma unroll 1
    for (int j = 0; j < 256; j++) {
        val = (val << 3) | (val >> 61);  // Rotate left by 3
    }
    out[i] = val;
}

// 64-bit compare
extern "C" __global__ void __launch_bounds__(32)
probe_int64_compare(int *out, const long long *a, const long long *b, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    long long va = a[i], vb = b[i];
    int result = 0;
    if (va > vb) result += 1;
    if (va < vb) result += 2;
    if (va == vb) result += 4;
    if ((unsigned long long)va > (unsigned long long)vb) result += 8;
    out[i] = result;
}

// __umul64hi: high 64 bits of 64x64->128 product
extern "C" __global__ void __launch_bounds__(32)
probe_umul64hi(unsigned long long *out,
               const unsigned long long *a,
               const unsigned long long *b) {
    int i = threadIdx.x;
    out[i] = __umul64hi(a[i], b[i]);
}

// Atomic 64-bit (compare with 32-bit atomic throughput)
extern "C" __global__ void __launch_bounds__(128)
probe_int64_atomic(unsigned long long *counter, int iters) {
    for (int j = 0; j < iters; j++)
        atomicAdd(counter, 1ULL);
}
