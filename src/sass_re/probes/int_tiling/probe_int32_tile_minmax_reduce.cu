
// INT32 simultaneous min+max warp reduction
extern "C" __global__ void __launch_bounds__(128)
int32_minmax(int *out_min, int *out_max, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int val=(i<n)?in[i]:0;
    int wmin=__reduce_min_sync(0xFFFFFFFF,val);
    int wmax=__reduce_max_sync(0xFFFFFFFF,val);
    if((threadIdx.x&31)==0){
        atomicMin(out_min,wmin);
        atomicMax(out_max,wmax);
    }
}
