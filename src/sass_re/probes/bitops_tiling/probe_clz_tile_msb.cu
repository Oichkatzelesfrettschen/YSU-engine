
// MSB extraction: get the most significant bit position
extern "C" __global__ void __launch_bounds__(128)
clz_msb(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i];
    // bfind returns position of highest set bit (or 0xFFFFFFFF if zero)
    int msb; asm volatile("bfind.u32 %0,%1;":"=r"(msb):"r"(v));
    out[i]=msb;
}
