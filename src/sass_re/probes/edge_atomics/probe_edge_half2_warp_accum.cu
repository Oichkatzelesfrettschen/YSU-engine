
#include <cuda_fp16.h>
// Half2 warp-cooperative accumulation: reduce 2 FP16 values per lane
// then single atomicAdd (FP32 promotion) from lane 0
extern "C" __global__ void __launch_bounds__(128)
edge_half2_warp(float *out_x, float *out_y, const __half2 *in, int n) {
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    __half2 val=(gi<n)?in[gi]:__float2half2_rn(0.0f);
    // Unpack to floats for reduction
    float x=__low2float(val), y=__high2float(val);
    // Warp butterfly reduce
    x+=__shfl_xor_sync(0xFFFFFFFF,x,16); y+=__shfl_xor_sync(0xFFFFFFFF,y,16);
    x+=__shfl_xor_sync(0xFFFFFFFF,x,8);  y+=__shfl_xor_sync(0xFFFFFFFF,y,8);
    x+=__shfl_xor_sync(0xFFFFFFFF,x,4);  y+=__shfl_xor_sync(0xFFFFFFFF,y,4);
    x+=__shfl_xor_sync(0xFFFFFFFF,x,2);  y+=__shfl_xor_sync(0xFFFFFFFF,y,2);
    x+=__shfl_xor_sync(0xFFFFFFFF,x,1);  y+=__shfl_xor_sync(0xFFFFFFFF,y,1);
    if((threadIdx.x&31)==0){atomicAdd(out_x,x);atomicAdd(out_y,y);}
}
