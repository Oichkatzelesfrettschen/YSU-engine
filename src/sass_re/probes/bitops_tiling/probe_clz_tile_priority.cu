
// Priority encoder: find highest set bit
extern "C" __global__ void __launch_bounds__(128)
clz_priority(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__ffs(in[i]); // First set bit (1-indexed, 0 if none)
}
