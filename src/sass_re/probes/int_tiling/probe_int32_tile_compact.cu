
// INT32 stream compaction (extract elements > threshold)
extern "C" __global__ void __launch_bounds__(128)
int32_compact(int *out, int *count, const int *in, int threshold, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int pred=(i<n)?(in[i]>threshold):0;
    unsigned ballot=__ballot_sync(0xFFFFFFFF,pred);
    int warp_count=__popc(ballot);
    int lane_offset=__popc(ballot&((1u<<(threadIdx.x&31))-1));
    int warp_base=0;
    if((threadIdx.x&31)==0&&warp_count>0) warp_base=atomicAdd(count,warp_count);
    warp_base=__shfl_sync(0xFFFFFFFF,warp_base,0);
    if(pred) out[warp_base+lane_offset]=in[i];
}
