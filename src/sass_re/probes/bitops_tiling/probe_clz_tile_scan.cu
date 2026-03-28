
// Prefix scan of CLZ values (inclusive scan via warp shuffle)
extern "C" __global__ void __launch_bounds__(32)
clz_prefix_scan(int *out, const unsigned *in, int n) {
    int lane=threadIdx.x, gi=blockIdx.x*32+lane;
    int val=(gi<n)?__clz(in[gi]):0;
    // Inclusive scan via shuffle
    for(int d=1;d<32;d<<=1){
        int t=__shfl_up_sync(0xFFFFFFFF,val,d);
        if(lane>=d) val+=t;
    }
    if(gi<n) out[gi]=val;
}
