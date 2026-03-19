/*
 * SASS RE Probe: INT128/UINT128 Software Emulation Paths
 * Isolates: The fastest 128-bit integer arithmetic on Ada via 2x64-bit ops
 *
 * Ada SM 8.9 has NO native 128-bit integer instructions. All 128-bit
 * integer operations must be emulated using pairs of 64-bit operations:
 *   ADD128 = IADD3 (low) + IADD3.X (high, with carry)
 *   MUL128 = IMAD.WIDE chain (4 partial products)
 *
 * This probe characterizes the emulation cost for:
 *   - 128-bit add (carry chain)
 *   - 128-bit multiply (schoolbook 4-part)
 *   - 128-bit shift
 *   - 128-bit compare
 *
 * Also probes UINT128 (unsigned) which uses the same instructions
 * but with unsigned overflow semantics.
 *
 * Key SASS:
 *   IADD3     -- low 64-bit add
 *   IADD3.X   -- high 64-bit add with carry input
 *   IMAD.WIDE -- 32x32->64 partial product
 *   IMAD.HI   -- high 32 bits of 32x32 multiply
 */

#include <cuda_runtime.h>

// 128-bit unsigned integer as two 64-bit halves
struct uint128_t {
    unsigned long long lo, hi;
};

// 128-bit signed integer
struct int128_t {
    unsigned long long lo;
    long long hi;
};

// 128-bit add: generates IADD3 + IADD3.X (carry chain)
__device__ __forceinline__
uint128_t add128(uint128_t a, uint128_t b) {
    uint128_t r;
    r.lo = a.lo + b.lo;
    r.hi = a.hi + b.hi + (r.lo < a.lo ? 1ULL : 0ULL);  // carry
    return r;
}

// 128-bit subtract
__device__ __forceinline__
uint128_t sub128(uint128_t a, uint128_t b) {
    uint128_t r;
    r.lo = a.lo - b.lo;
    r.hi = a.hi - b.hi - (a.lo < b.lo ? 1ULL : 0ULL);  // borrow
    return r;
}

// 128-bit left shift (by constant amount < 64)
__device__ __forceinline__
uint128_t shl128(uint128_t a, int shift) {
    uint128_t r;
    if (shift == 0) return a;
    if (shift < 64) {
        r.hi = (a.hi << shift) | (a.lo >> (64 - shift));
        r.lo = a.lo << shift;
    } else {
        r.hi = a.lo << (shift - 64);
        r.lo = 0;
    }
    return r;
}

// 128-bit right shift (unsigned)
__device__ __forceinline__
uint128_t shr128(uint128_t a, int shift) {
    uint128_t r;
    if (shift == 0) return a;
    if (shift < 64) {
        r.lo = (a.lo >> shift) | (a.hi << (64 - shift));
        r.hi = a.hi >> shift;
    } else {
        r.lo = a.hi >> (shift - 64);
        r.hi = 0;
    }
    return r;
}

// 128-bit compare (unsigned)
__device__ __forceinline__
int cmp128(uint128_t a, uint128_t b) {
    if (a.hi != b.hi) return (a.hi > b.hi) ? 1 : -1;
    if (a.lo != b.lo) return (a.lo > b.lo) ? 1 : -1;
    return 0;
}

// 128-bit add chain for latency measurement
extern "C" __global__ void __launch_bounds__(32)
probe_uint128_add(unsigned long long *out, const unsigned long long *in) {
    int i = threadIdx.x;
    uint128_t acc;
    acc.lo = in[i * 2];
    acc.hi = in[i * 2 + 1];
    uint128_t one = {1ULL, 0ULL};

    // 256-deep 128-bit add chain
    #pragma unroll 1
    for (int j = 0; j < 256; j++)
        acc = add128(acc, one);

    out[i * 2] = acc.lo;
    out[i * 2 + 1] = acc.hi;
}

// 128-bit shift chain
extern "C" __global__ void __launch_bounds__(32)
probe_uint128_shift(unsigned long long *out, const unsigned long long *in) {
    int i = threadIdx.x;
    uint128_t val;
    val.lo = in[i * 2];
    val.hi = in[i * 2 + 1];

    // Alternating left/right shifts
    #pragma unroll 1
    for (int j = 0; j < 256; j++) {
        val = shl128(val, 3);
        val = shr128(val, 2);
    }

    out[i * 2] = val.lo;
    out[i * 2 + 1] = val.hi;
}

// INT128 signed operations
extern "C" __global__ void __launch_bounds__(32)
probe_int128_signed(long long *out, const long long *in) {
    int i = threadIdx.x;
    int128_t val;
    val.lo = (unsigned long long)in[i * 2];
    val.hi = in[i * 2 + 1];

    // Signed 128-bit absolute value (negate if negative)
    if (val.hi < 0) {
        // Two's complement negation: ~val + 1
        val.lo = ~val.lo + 1;
        val.hi = ~(unsigned long long)val.hi + (val.lo == 0 ? 1 : 0);
    }

    out[i * 2] = (long long)val.lo;
    out[i * 2 + 1] = val.hi;
}

// 128-bit multiply (lo*lo only, 64x64->128)
// This is the pattern used in double-double arithmetic (Knuth 2-sum)
extern "C" __global__ void __launch_bounds__(32)
probe_uint128_mul64x64(unsigned long long *out,
                       const unsigned long long *a,
                       const unsigned long long *b) {
    int i = threadIdx.x;
    unsigned long long va = a[i], vb = b[i];

    // 64x64 -> 128 multiply via __umul64hi + regular multiply
    unsigned long long lo = va * vb;
    unsigned long long hi = __umul64hi(va, vb);

    out[i * 2] = lo;
    out[i * 2 + 1] = hi;
}
