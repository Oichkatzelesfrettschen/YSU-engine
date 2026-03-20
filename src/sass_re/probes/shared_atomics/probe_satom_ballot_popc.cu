
// Shared atomic via ballot+popc (warp-aggregated pattern)
// Uses ballot to count, then single atomicAdd per warp
extern "C" __global__ void __launch_bounds__(256)
satom_ballot_agg(unsigned *out, const float *in, float threshold, int n) {
    __shared__ unsigned s_count;
    if(threadIdx.x==0) s_count=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    int pred=(gi<n)?(in[gi]>threshold):0;
    unsigned ballot=__ballot_sync(0xFFFFFFFF,pred);
    // Only lane 0 does the smem atomic (32x fewer atomics!)
    if((threadIdx.x&31)==0){
        int warp_count=__popc(ballot);
        if(warp_count>0) atomicAdd(&s_count,(unsigned)warp_count);
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_count);
}
