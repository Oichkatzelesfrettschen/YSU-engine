
#include <cuda_bf16.h>
// BF16 shared atomic add (via FP32 promotion)
extern "C" __global__ void __launch_bounds__(128)
satom_bf16_add(float *out, const __nv_bfloat16 *in, int n) {
    __shared__ float s_sum;
    if(threadIdx.x==0) s_sum=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s_sum,__bfloat162float(in[gi]));
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
