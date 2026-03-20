
// POPC + REDUX.SUM warp reduction
extern "C" __global__ void __launch_bounds__(128)
popc_redux(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int bits=(i<n)?__popc(in[i]):0;
    int warp_total=__reduce_add_sync(0xFFFFFFFF,bits);
    if((threadIdx.x&31)==0) out[blockIdx.x*(blockDim.x/32)+(threadIdx.x/32)]=warp_total;
}
