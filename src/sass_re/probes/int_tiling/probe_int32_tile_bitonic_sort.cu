
// INT32 bitonic sort (warp-level, 32 elements)
extern "C" __global__ void __launch_bounds__(32)
int32_bitonic_warp(int *data, int n) {
    int tid=threadIdx.x, gi=blockIdx.x*32+tid;
    int val=(gi<n)?data[gi]:0x7FFFFFFF;
    // Bitonic sort network via warp shuffle
    for(int k=2;k<=32;k<<=1){
        for(int j=k>>1;j>0;j>>=1){
            int partner=val;
            int ixj=tid^j;
            partner=__shfl_sync(0xFFFFFFFF,val,ixj);
            int cmp=((tid&k)==0)?(val>partner):(val<partner);
            if(cmp) val=partner;
        }
    }
    if(gi<n) data[gi]=val;
}
