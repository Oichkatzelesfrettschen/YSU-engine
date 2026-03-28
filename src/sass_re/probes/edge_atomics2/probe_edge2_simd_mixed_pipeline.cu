
#include <cuda_fp16.h>
// SIMD mixed: load float4, convert to half2 pairs, FMA, atomicAdd result
extern "C" __global__ void __launch_bounds__(128)
edge2_simd_mixed(float *out, const float4 *f4_in, int n) {
    __shared__ float s_sum;
    if(threadIdx.x==0) s_sum=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float4 v=f4_in[gi];
        // Convert to half2 pairs and FMA
        __half2 h01=__floats2half2_rn(v.x,v.y);
        __half2 h23=__floats2half2_rn(v.z,v.w);
        __half2 prod=__hmul2(h01,h23); // (x*z, y*w)
        float result=__low2float(prod)+__high2float(prod);
        atomicAdd(&s_sum,result);
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
