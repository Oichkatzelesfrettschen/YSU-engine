
// BFE/BFI with varying offsets and widths to trigger all encoding variants
extern "C" __global__ void __launch_bounds__(32)
bfe_bfi_sweep(unsigned *out, const unsigned *in) {
    int i=threadIdx.x;
    unsigned v=in[i], r;
    // BFE with different offset/width combos
    asm volatile("bfe.u32 %0,%1,0,1;":"=r"(r):"r"(v)); out[i*12]=r;    // 1 bit from pos 0
    asm volatile("bfe.u32 %0,%1,4,4;":"=r"(r):"r"(v)); out[i*12+1]=r;  // 4 bits from pos 4
    asm volatile("bfe.u32 %0,%1,16,16;":"=r"(r):"r"(v)); out[i*12+2]=r; // upper half
    asm volatile("bfe.u32 %0,%1,31,1;":"=r"(r):"r"(v)); out[i*12+3]=r;  // MSB only
    asm volatile("bfe.s32 %0,%1,24,8;":"=r"(r):"r"(v)); out[i*12+4]=r;  // signed top byte
    asm volatile("bfe.s32 %0,%1,0,8;":"=r"(r):"r"(v)); out[i*12+5]=r;   // signed bottom byte
    // BFI with different positions
    unsigned mask=0xDEAD;
    asm volatile("bfi.b32 %0,%1,%2,0,8;":"=r"(r):"r"(mask),"r"(v)); out[i*12+6]=r;   // insert byte at 0
    asm volatile("bfi.b32 %0,%1,%2,8,8;":"=r"(r):"r"(mask),"r"(v)); out[i*12+7]=r;   // insert at 8
    asm volatile("bfi.b32 %0,%1,%2,16,8;":"=r"(r):"r"(mask),"r"(v)); out[i*12+8]=r;  // insert at 16
    asm volatile("bfi.b32 %0,%1,%2,24,8;":"=r"(r):"r"(mask),"r"(v)); out[i*12+9]=r;  // insert at 24
    asm volatile("bfi.b32 %0,%1,%2,0,16;":"=r"(r):"r"(mask),"r"(v)); out[i*12+10]=r; // insert half
    asm volatile("bfi.b32 %0,%1,%2,4,4;":"=r"(r):"r"(mask),"r"(v)); out[i*12+11]=r;  // insert nibble
}
