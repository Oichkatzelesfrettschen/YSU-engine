
// The OPTIMAL shared atomic pattern: SHFL reduce + REDUX.SUM + single atomic
// Compares: (a) every-thread atomic, (b) warp SHFL+atomic, (c) REDUX+atomic
extern "C" __global__ void __launch_bounds__(256)
edge2_optimal_a(int *out, const int *in, int n) {
    // (a) Naive: every thread atomicAdd to smem
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s,in[gi]);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s);
}
extern "C" __global__ void __launch_bounds__(256)
edge2_optimal_b(int *out, const int *in, int n) {
    // (b) Warp SHFL reduce then 1 atomic per warp
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int val=(gi<n)?in[gi]:0;
    for(int off=16;off>0;off/=2) val+=__shfl_xor_sync(0xFFFFFFFF,val,off);
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    if((threadIdx.x&31)==0) atomicAdd(&s,val);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s);
}
extern "C" __global__ void __launch_bounds__(256)
edge2_optimal_c(int *out, const int *in, int n) {
    // (c) REDUX.SUM then 1 atomic per warp (FASTEST)
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int val=(gi<n)?in[gi]:0;
    int warp_sum=__reduce_add_sync(0xFFFFFFFF,val);
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    if((threadIdx.x&31)==0) atomicAdd(&s,warp_sum);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s);
}
