
// INT8 dp4a with shared atomic: each warp computes dp4a, atomicAdd result
extern "C" __global__ void __launch_bounds__(128)
edge2_dp4a_atomic(int *out, const int *a_packed, const int *b_packed, int n) {
    __shared__ int s_acc;
    if(threadIdx.x==0) s_acc=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int dot = (gi < n) ? __dp4a(a_packed[gi], b_packed[gi], 0) : 0;
    int warp_sum=__reduce_add_sync(0xFFFFFFFF,dot);
    if((threadIdx.x&31)==0) atomicAdd(&s_acc,warp_sum);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_acc);
}
