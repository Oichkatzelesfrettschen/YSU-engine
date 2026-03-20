
// 64-bit CLZ via two 32-bit CLZ
extern "C" __global__ void __launch_bounds__(128)
clz_64bit(int *out, const unsigned long long *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned long long v=in[i];
    unsigned hi=(unsigned)(v>>32), lo=(unsigned)(v&0xFFFFFFFFu);
    int clz_hi=__clz(hi);
    out[i]=(clz_hi<32)?clz_hi:(32+__clz(lo));
}
