
// INT4 warp-level nibble reduction via ballot+popc
extern "C" __global__ void __launch_bounds__(32)
int4_tile_reduce(int *out, const unsigned char *in, int n) {
    int tid=threadIdx.x, gi=blockIdx.x*32+tid;
    int val=0;
    if (gi<n) { val=in[gi]&0xF; if(val>=8)val-=16; }
    int pos = (val>0)?1:0;
    unsigned ballot = __ballot_sync(0xFFFFFFFF, pos);
    int count = __popc(ballot);
    if (tid==0) out[blockIdx.x]=count;
}
