
#include <cuda_fp16.h>
// Mixed precision: INT8 weights * FP16 activations, accumulate via shared atomic
extern "C" __global__ void __launch_bounds__(128)
edge_mixed_dot(float *out, const signed char *weights, const __half *activations, int K) {
    __shared__ float s_dot;
    if(threadIdx.x==0) s_dot=0.0f;
    __syncthreads();
    int tid=threadIdx.x;
    float local_sum=0.0f;
    for(int k=tid;k<K;k+=blockDim.x){
        float w=(float)weights[k];
        float a=__half2float(activations[k]);
        local_sum=fmaf(w,a,local_sum);
    }
    atomicAdd(&s_dot,local_sum);
    __syncthreads();
    if(tid==0) atomicAdd(out,s_dot);
}
