
// SHF (funnel shift) with all direction/type combinations
extern "C" __global__ void __launch_bounds__(32)
shf_sweep(unsigned *out, const unsigned *a, const unsigned *b) {
    int i=threadIdx.x;
    unsigned va=a[i],vb=b[i],r;
    // Right shifts
    asm volatile("shf.r.wrap.b32 %0,%1,%2,4;":"=r"(r):"r"(va),"r"(vb)); out[i*8]=r;
    asm volatile("shf.r.clamp.b32 %0,%1,%2,4;":"=r"(r):"r"(va),"r"(vb)); out[i*8+1]=r;
    // Left shifts
    asm volatile("shf.l.wrap.b32 %0,%1,%2,4;":"=r"(r):"r"(va),"r"(vb)); out[i*8+2]=r;
    asm volatile("shf.l.clamp.b32 %0,%1,%2,4;":"=r"(r):"r"(va),"r"(vb)); out[i*8+3]=r;
    // Variable shift amounts
    unsigned shift=va&31;
    asm volatile("shf.r.wrap.b32 %0,%1,%2,%3;":"=r"(r):"r"(va),"r"(vb),"r"(shift)); out[i*8+4]=r;
    asm volatile("shf.l.wrap.b32 %0,%1,%2,%3;":"=r"(r):"r"(va),"r"(vb),"r"(shift)); out[i*8+5]=r;
    // 64-bit shift via SHF pair
    unsigned lo=va, hi=vb;
    asm volatile("shf.r.wrap.b32 %0,%1,%2,8;":"=r"(r):"r"(lo),"r"(hi)); out[i*8+6]=r;
    asm volatile("shf.l.wrap.b32 %0,%1,%2,8;":"=r"(r):"r"(hi),"r"(lo)); out[i*8+7]=r;
}
