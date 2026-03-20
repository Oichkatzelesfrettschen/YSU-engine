
// L1 norm (sum of absolute values)
extern "C" __global__ void __launch_bounds__(128)
iabs_l1norm(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int val=(i<n)?abs(in[i]):0;
    int warp_sum=__reduce_add_sync(0xFFFFFFFF,val);
    if((threadIdx.x&31)==0) atomicAdd(out,warp_sum);
}
