
// Count set bits in bitmask array (sparse occupancy counting)
extern "C" __global__ void __launch_bounds__(256)
popc_mask_count(int *out, const unsigned *masks, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int count=0;
    if(i<n) count=__popc(masks[i]);
    int warp_total=__reduce_add_sync(0xFFFFFFFF,count);
    if((threadIdx.x&31)==0) atomicAdd(out,warp_total);
}
