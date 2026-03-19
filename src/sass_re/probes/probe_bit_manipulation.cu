/*
 * SASS RE Probe: Bit Manipulation Instructions
 * Isolates: BMSK, BREV, SGXT, FLO, POPC chains, BFI/BFE patterns
 *
 * These instructions are used in:
 *   - Hash functions (BREV for bit reversal, POPC for popcount)
 *   - FFT (BREV for bit-reversal permutation)
 *   - Nibble packing (BFI/BFE for bit field insert/extract)
 *   - Sparse data structures (FLO for leading zero count)
 *   - Sign extension (SGXT for narrowing conversions)
 *
 * Key SASS:
 *   BMSK      -- generate bit mask (N bits starting at position P)
 *   BREV      -- reverse all 32 bits
 *   SGXT      -- sign extend from bit position N
 *   FLO       -- find leading one (count leading zeros)
 *   POPC      -- population count (count set bits)
 *   BFI       -- bit field insert
 *   BFE       -- bit field extract (already in probe_bitwise, but chains here)
 */

// BREV: bit reversal (used in FFT butterfly permutation)
extern "C" __global__ void __launch_bounds__(32)
probe_brev(unsigned *out, const unsigned *in) {
    int i = threadIdx.x;
    unsigned val = in[i];

    // __brev() generates BREV instruction
    unsigned reversed = __brev(val);

    // Chain: reverse, then reverse again (should be identity)
    unsigned double_rev = __brev(reversed);

    out[i] = reversed;
    out[i + 32] = double_rev;
}

// BREV dependent chain for latency measurement
extern "C" __global__ void __launch_bounds__(32)
probe_brev_chain(unsigned *out, const unsigned *in) {
    int i = threadIdx.x;
    unsigned val = in[i];
    long long t0, t1;

    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int j = 0; j < 512; j++)
        val = __brev(val);
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));

    out[i] = val;
    if (i == 0) {
        // Store timing in last elements
        ((long long*)out)[16] = t1 - t0;
        ((long long*)out)[17] = 512;
    }
}

// POPC: population count chains
extern "C" __global__ void __launch_bounds__(32)
probe_popc_chain(int *out, const unsigned *in) {
    int i = threadIdx.x;
    unsigned val = in[i];
    int count = 0;

    // POPC chain: count bits, use result, count again
    #pragma unroll 1
    for (int j = 0; j < 512; j++) {
        count = __popc(val);
        val = val ^ (unsigned)count;  // Mix result back
    }

    out[i] = count;
}

// FLO: find leading one (count leading zeros)
extern "C" __global__ void __launch_bounds__(32)
probe_flo(int *out, const unsigned *in) {
    int i = threadIdx.x;
    unsigned val = in[i];

    // __clz() generates FLO instruction
    int lz = __clz(val);          // Count leading zeros
    int ffs_val = __ffs(val);     // Find first set bit (1-indexed)

    out[i] = lz;
    out[i + 32] = ffs_val;
}

// BFI: bit field insert patterns (pack multiple small values)
extern "C" __global__ void __launch_bounds__(32)
probe_bfi_pack(unsigned *out, const unsigned *a, const unsigned *b,
               const unsigned *c) {
    int i = threadIdx.x;
    unsigned va = a[i] & 0xFF;   // 8-bit value a
    unsigned vb = b[i] & 0xFF;   // 8-bit value b
    unsigned vc = c[i] & 0xFFFF; // 16-bit value c

    // Pack: [c:16][b:8][a:8] into one 32-bit word
    unsigned packed = va;                          // bits [0:7]
    // BFI: insert vb at bits [8:15]
    asm volatile("bfi.b32 %0, %1, %0, 8, 8;" : "+r"(packed) : "r"(vb));
    // BFI: insert vc at bits [16:31]
    asm volatile("bfi.b32 %0, %1, %0, 16, 16;" : "+r"(packed) : "r"(vc));

    out[i] = packed;
}

// BFE: bit field extract patterns (unpack)
extern "C" __global__ void __launch_bounds__(32)
probe_bfe_unpack(unsigned *out_a, unsigned *out_b, unsigned *out_c,
                 const unsigned *packed_in) {
    int i = threadIdx.x;
    unsigned packed = packed_in[i];

    unsigned a, b, c;
    // BFE: extract bits [0:7]
    asm volatile("bfe.u32 %0, %1, 0, 8;" : "=r"(a) : "r"(packed));
    // BFE: extract bits [8:15]
    asm volatile("bfe.u32 %0, %1, 8, 8;" : "=r"(b) : "r"(packed));
    // BFE: extract bits [16:31]
    asm volatile("bfe.u32 %0, %1, 16, 16;" : "=r"(c) : "r"(packed));

    out_a[i] = a;
    out_b[i] = b;
    out_c[i] = c;
}

// BMSK: bit mask generation
extern "C" __global__ void __launch_bounds__(32)
probe_bmsk(unsigned *out) {
    int i = threadIdx.x;

    // Generate masks of various widths
    // BMSK generates a mask of N bits: (1 << N) - 1
    unsigned m1 = (1u << 1) - 1;    // 0x00000001
    unsigned m4 = (1u << 4) - 1;    // 0x0000000F
    unsigned m8 = (1u << 8) - 1;    // 0x000000FF
    unsigned m16 = (1u << 16) - 1;  // 0x0000FFFF
    unsigned m_tid = (1u << (i & 31)) - 1;  // Variable width

    out[i * 5 + 0] = m1;
    out[i * 5 + 1] = m4;
    out[i * 5 + 2] = m8;
    out[i * 5 + 3] = m16;
    out[i * 5 + 4] = m_tid;
}
