
// Max-CLZ warp reduction (find the most-zero-padded value)
extern "C" __global__ void __launch_bounds__(128)
clz_max_reduce(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int clz=(i<n)?__clz(in[i]):32;
    int warp_max=__reduce_max_sync(0xFFFFFFFF,clz);
    if((threadIdx.x&31)==0) out[blockIdx.x*(blockDim.x/32)+(threadIdx.x/32)]=warp_max;
}
