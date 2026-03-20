
// Compare: REDUX.SUM then single atomic vs many atomics
extern "C" __global__ void __launch_bounds__(128)
satom_redux_single(int *out, const int *in, int n) {
    // Method 1: REDUX.SUM + 1 atomic per warp (fast path)
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int val=(gi<n)?in[gi]:0;
    int warp_sum=__reduce_add_sync(0xFFFFFFFF,val);
    if((threadIdx.x&31)==0 && warp_sum!=0) atomicAdd(out,warp_sum);
}

extern "C" __global__ void __launch_bounds__(128)
satom_naive_all(int *out, const int *in, int n) {
    // Method 2: every thread does atomicAdd (slow path)
    __shared__ int s_sum;
    if(threadIdx.x==0) s_sum=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s_sum,in[gi]);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
