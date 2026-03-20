
// REDUX.SUM precompute then single shared atomic (optimal path)
extern "C" __global__ void __launch_bounds__(256)
edge_redux_atomic(int *out, const int *in, int n) {
    __shared__ int s_total;
    if(threadIdx.x==0) s_total=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int val=(gi<n)?in[gi]:0;
    // REDUX.SUM: single instruction reduces entire warp
    int warp_sum=__reduce_add_sync(0xFFFFFFFF,val);
    // Single atomic per warp (not per thread!)
    if((threadIdx.x&31)==0 && warp_sum!=0) atomicAdd(&s_total,warp_sum);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_total);
}
