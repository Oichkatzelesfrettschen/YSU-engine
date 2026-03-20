
// INT16 warp reduction
extern "C" __global__ void __launch_bounds__(128)
int16_reduce(int *out, const short *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int val=(i<n)?(int)in[i]:0;
    int wsum=__reduce_add_sync(0xFFFFFFFF,val);
    if((threadIdx.x&31)==0) atomicAdd(out,wsum);
}
