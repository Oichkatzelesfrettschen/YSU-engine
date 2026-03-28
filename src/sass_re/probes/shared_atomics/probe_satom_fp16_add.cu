
#include <cuda_fp16.h>
// FP16 shared atomic add (via FP32 promotion on Ada)
extern "C" __global__ void __launch_bounds__(128)
satom_f16_add(float *out, const __half *in, int n) {
    __shared__ float s_sum;
    if(threadIdx.x==0) s_sum=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s_sum,__half2float(in[gi])); // Promote to FP32 for atomic
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
