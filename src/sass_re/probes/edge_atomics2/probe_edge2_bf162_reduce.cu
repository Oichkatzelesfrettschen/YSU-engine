
#include <cuda_bf16.h>
// BF16x2 packed reduce: unpack, warp reduce, single FP32 atomic per component
extern "C" __global__ void __launch_bounds__(128)
edge2_bf162_reduce(float *out, const __nv_bfloat162 *in, int n) {
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    __nv_bfloat162 v=(gi<n)?in[gi]:__float2bfloat162_rn(0.0f);
    float lo=__low2float(v), hi=__high2float(v);
    // Warp-level butterfly reduce both components
    for(int off=16;off>0;off/=2){lo+=__shfl_xor_sync(0xFFFFFFFF,lo,off);hi+=__shfl_xor_sync(0xFFFFFFFF,hi,off);}
    __shared__ float sx,sy;
    if(threadIdx.x==0){sx=0;sy=0;}
    __syncthreads();
    if((threadIdx.x&31)==0){atomicAdd(&sx,lo);atomicAdd(&sy,hi);}
    __syncthreads();
    if(threadIdx.x==0){atomicAdd(&out[0],sx);atomicAdd(&out[1],sy);}
}
