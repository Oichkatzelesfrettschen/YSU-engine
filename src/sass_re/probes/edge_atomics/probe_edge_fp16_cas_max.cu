
#include <cuda_fp16.h>
// FP16 atomicMax on shared memory via 32-bit CAS
extern "C" __global__ void __launch_bounds__(128)
edge_f16_smax(float *out, const __half *in, int n) {
    __shared__ unsigned int s_max_word; // 32-bit aligned; half bits in low 16
    if(threadIdx.x==0) s_max_word=0; // 0 = half(0.0)
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        __half val=in[gi];
        unsigned short val_bits=*(unsigned short*)&val;
        // CAS loop on the 32-bit word; half lives in low 16 bits
        unsigned int old=s_max_word;
        while(1){
            unsigned short old_bits=(unsigned short)(old&0xFFFF);
            __half old_val=*(__half*)&old_bits;
            if(__hle(val,old_val)) break; // val <= old, done
            unsigned int new_word=(old&0xFFFF0000u)|val_bits;
            unsigned int prev=atomicCAS(&s_max_word,old,new_word);
            if(prev==old)break;
            old=prev;
        }
    }
    __syncthreads();
    if(threadIdx.x==0){
        unsigned short result_bits=(unsigned short)(s_max_word&0xFFFF);
        __half result=*(__half*)&result_bits;
        atomicAdd(out,__half2float(result));
    }
}
