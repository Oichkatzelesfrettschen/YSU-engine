
#include <cuda_fp16.h>
#include <cuda_bf16.h>
// Mixed: half2 HFMA2 + bf162 HFMA2.BF16 results accumulated via shared atomic
extern "C" __global__ void __launch_bounds__(128)
edge2_mixed_f16_bf16(float *out, const __half2 *f16_in, const __nv_bfloat162 *bf16_in, int n) {
    __shared__ float s_f16_sum, s_bf16_sum;
    if(threadIdx.x==0){s_f16_sum=0;s_bf16_sum=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        // FP16 half2 FMA
        __half2 hv=f16_in[gi];
        __half2 hone=__float2half2_rn(1.0f);
        __half2 hresult=__hfma2(hv,hv,hone); // x^2+1
        float f16_val=__low2float(hresult)+__high2float(hresult);
        // BF16 bf162 FMA
        __nv_bfloat162 bv=bf16_in[gi];
        __nv_bfloat162 bone=__float2bfloat162_rn(1.0f);
        __nv_bfloat162 bresult=__hfma2(bv,bv,bone);
        float bf16_val=__low2float(bresult)+__high2float(bresult);
        atomicAdd(&s_f16_sum,f16_val);
        atomicAdd(&s_bf16_sum,bf16_val);
    }
    __syncthreads();
    if(threadIdx.x==0){atomicAdd(&out[0],s_f16_sum);atomicAdd(&out[1],s_bf16_sum);}
}
