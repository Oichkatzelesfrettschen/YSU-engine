
#include <cuda_fp8.h>
#include <cuda_fp16.h>
// FP8 E4M3 block-level reduction: decode to FP32, reduce via shared atomic
extern "C" __global__ void __launch_bounds__(128)
edge_fp8_reduce(float *out, const __nv_fp8_storage_t *in, int n) {
    __shared__ float s_sum;
    if(threadIdx.x==0) s_sum=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        __half_raw hr=__nv_cvt_fp8_to_halfraw(in[gi],__NV_E4M3);
        __half h; __builtin_memcpy(&h,&hr,sizeof(h));
        atomicAdd(&s_sum,__half2float(h));
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
