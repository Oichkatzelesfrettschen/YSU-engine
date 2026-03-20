
// __umul64hi: high 64 bits of 64x64->128 product
extern "C" __global__ void __launch_bounds__(128)
int64_umul64hi(unsigned long long *out, const unsigned long long *a, const unsigned long long *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__umul64hi(a[i],b[i]);
}
