
// PRMT byte permute with all mode variants
extern "C" __global__ void __launch_bounds__(32)
prmt_all_modes(unsigned *out, const unsigned *a, const unsigned *b) {
    int i=threadIdx.x;
    unsigned va=a[i], vb=b[i];
    unsigned r;
    // Mode 0: byte select (default)
    asm volatile("prmt.b32 %0, %1, %2, 0x3210;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8]=r;
    // F4E: four-byte extract (funnel shift by byte)
    asm volatile("prmt.b32.f4e %0, %1, %2, 1;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+1]=r;
    // B4E: byte4 extract (reverse funnel)
    asm volatile("prmt.b32.b4e %0, %1, %2, 1;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+2]=r;
    // RC8: replicate byte to all 4 positions
    asm volatile("prmt.b32.rc8 %0, %1, %2, 0;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+3]=r;
    // ECL: edge clamp left
    asm volatile("prmt.b32.ecl %0, %1, %2, 1;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+4]=r;
    // ECR: edge clamp right
    asm volatile("prmt.b32.ecr %0, %1, %2, 1;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+5]=r;
    // RC16: replicate short to both positions
    asm volatile("prmt.b32.rc16 %0, %1, %2, 0;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+6]=r;
    // Byte reverse (endian swap)
    asm volatile("prmt.b32 %0, %1, %2, 0x0123;" : "=r"(r) : "r"(va), "r"(vb));
    out[i*8+7]=r;
}
