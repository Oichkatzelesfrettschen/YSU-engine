
// INT16 inclusive prefix scan via warp shuffle
extern "C" __global__ void __launch_bounds__(32)
int16_scan(int *out, const short *in, int n) {
    int lane=threadIdx.x, gi=blockIdx.x*32+lane;
    int val=(gi<n)?(int)in[gi]:0;
    for(int d=1;d<32;d<<=1){int t=__shfl_up_sync(0xFFFFFFFF,val,d);if(lane>=d)val+=t;}
    if(gi<n)out[gi]=val;
}
