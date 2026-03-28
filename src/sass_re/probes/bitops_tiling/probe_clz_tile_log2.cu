
// Integer log2 via CLZ: log2(x) = 31 - __clz(x)
extern "C" __global__ void __launch_bounds__(128)
clz_log2(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i];
    out[i]=(v>0)?(31-__clz(v)):(-1);
}
