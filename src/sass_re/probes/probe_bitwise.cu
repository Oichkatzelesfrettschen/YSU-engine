/*
 * SASS RE Probe: Bitwise / Bit-manipulation
 * Isolates: LOP3, SHF, PRMT, BFI, BFE, FLO, POPC
 *
 * LOP3 is the universal 3-input logic op (truth-table LUT).
 * SHF is the funnel shifter (double-width shift).
 * PRMT is the byte-permute instruction.
 */

// LOP3: 3-input logic using truth-table LUT
// LOP3.LUT Rd, Ra, Rb, Rc, <immLut>
// immLut = truth table encoded as 8-bit value
extern "C" __global__ void __launch_bounds__(32)
probe_lop3(unsigned *out, const unsigned *a, const unsigned *b, const unsigned *c) {
    int i = threadIdx.x;
    unsigned x = a[i];
    unsigned y = b[i];
    unsigned z = c[i];

    // AND:       x & y       -> LOP3 lut=0xC0 (when z is ignored)
    unsigned r_and = x & y;

    // OR:        x | y       -> LOP3 lut=0xFC
    unsigned r_or = x | y;

    // XOR:       x ^ y       -> LOP3 lut=0x3C
    unsigned r_xor = x ^ y;

    // 3-input:   (x & y) | z -> LOP3 lut=0xFC if folded, or explicit 3-input
    unsigned r_3in = (x & y) | z;

    // MAJ3:      majority    -> LOP3 lut=0xE8
    unsigned r_maj = (x & y) | (y & z) | (x & z);

    // NOT + AND: (~x) & y    -> LOP3 lut=0x30
    unsigned r_nand = (~x) & y;

    // XOR3:      x ^ y ^ z  -> LOP3 lut=0x96
    unsigned r_xor3 = x ^ y ^ z;

    out[i] = r_and ^ r_or ^ r_xor ^ r_3in ^ r_maj ^ r_nand ^ r_xor3;
}

// SHF: funnel shift (64-bit shift using two 32-bit registers)
extern "C" __global__ void __launch_bounds__(32)
probe_shf(unsigned *out, const unsigned *a, const unsigned *b) {
    int i = threadIdx.x;
    unsigned hi = a[i];
    unsigned lo = b[i];

    // SHF.L: shift left (funnel)
    // __funnelshift_l(lo, hi, shift) -> SHF.L.W
    unsigned r1 = __funnelshift_l(lo, hi, 4);
    unsigned r2 = __funnelshift_l(lo, hi, 8);
    unsigned r3 = __funnelshift_l(lo, hi, 16);

    // SHF.R: shift right (funnel)
    unsigned r4 = __funnelshift_r(lo, hi, 4);
    unsigned r5 = __funnelshift_r(lo, hi, 8);
    unsigned r6 = __funnelshift_r(lo, hi, 16);

    // SHF.R.C: shift right with clamp
    unsigned r7 = __funnelshift_rc(lo, hi, 4);

    // SHF.L.C: shift left with clamp
    unsigned r8 = __funnelshift_lc(lo, hi, 4);

    out[i] = r1 ^ r2 ^ r3 ^ r4 ^ r5 ^ r6 ^ r7 ^ r8;
}

// PRMT: byte permute
extern "C" __global__ void __launch_bounds__(32)
probe_prmt(unsigned *out, const unsigned *a, const unsigned *b) {
    int i = threadIdx.x;
    unsigned x = a[i];
    unsigned y = b[i];

    // __byte_perm(x, y, selector): each 4-bit field in selector picks a byte
    // from the concatenation {y, x} (8 bytes total, indexed 0-7)
    unsigned r1 = __byte_perm(x, y, 0x3210);  // identity for x
    unsigned r2 = __byte_perm(x, y, 0x7654);  // identity for y
    unsigned r3 = __byte_perm(x, y, 0x0123);  // reverse bytes of x
    unsigned r4 = __byte_perm(x, y, 0x5140);  // shuffle bytes across x,y
    unsigned r5 = __byte_perm(x, y, 0x0000);  // broadcast byte 0 of x

    out[i] = r1 ^ r2 ^ r3 ^ r4 ^ r5;
}

// BFI/BFE: bit field insert / extract
extern "C" __global__ void __launch_bounds__(32)
probe_bfi_bfe(unsigned *out, const unsigned *a, const unsigned *b) {
    int i = threadIdx.x;
    unsigned x = a[i];
    unsigned y = b[i];

    // BFE: extract bits [8:15] from x (inline PTX for CUDA 13.1 compat)
    unsigned e1;
    asm("bfe.u32 %0, %1, 8, 8;" : "=r"(e1) : "r"(x));

    // BFI: insert low 8 bits of y into x at position 16
    unsigned i1;
    asm("bfi.b32 %0, %1, %2, 16, 8;" : "=r"(i1) : "r"(y), "r"(x));

    unsigned e2;
    asm("bfe.u32 %0, %1, 0, 16;" : "=r"(e2) : "r"(x));
    unsigned i2;
    asm("bfi.b32 %0, %1, %2, 0, 16;" : "=r"(i2) : "r"(y), "r"(x));

    out[i] = e1 ^ i1 ^ e2 ^ i2;
}

// FLO: find leading one (like CLZ but returns bit position)
// POPC: population count (number of 1-bits)
extern "C" __global__ void __launch_bounds__(32)
probe_flo_popc(unsigned *out, const unsigned *a) {
    int i = threadIdx.x;
    unsigned x = a[i];

    unsigned clz = __clz(x);         // FLO or CLZ variant
    unsigned pop = __popc(x);         // POPC
    unsigned ffs = __ffs(x);          // FLO.U32 (find first set)
    unsigned brev = __brev(x);        // BREV (bit reverse)
    unsigned clz2 = __clz(brev);     // Another FLO on reversed

    out[i] = clz + pop + ffs + brev + clz2;
}
