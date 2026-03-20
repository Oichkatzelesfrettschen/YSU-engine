
#include <cuda_fp16.h>
// FP16 atomicMax on shared memory via short CAS
extern "C" __global__ void __launch_bounds__(128)
edge_f16_smax(float *out, const __half *in, int n) {
    __shared__ unsigned short s_max_bits; // Store half as bits
    if(threadIdx.x==0) s_max_bits=0; // 0 = half(0.0)
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        __half val=in[gi];
        unsigned short val_bits=*(unsigned short*)&val;
        // CAS loop on unsigned short (2 shorts packed in int)
        // Operate on the containing 32-bit word
        int *word_addr=(int*)&s_max_bits;
        int old=*word_addr;
        while(1){
            unsigned short old_bits=(unsigned short)(old&0xFFFF);
            __half old_val=*(__half*)&old_bits;
            if(__hle(val,old_val)) break; // val <= old, done
            int new_word=(old&0xFFFF0000)|val_bits;
            int prev=atomicCAS(word_addr,old,new_word);
            if(prev==old)break;
            old=prev;
        }
    }
    __syncthreads();
    if(threadIdx.x==0){
        __half result=*(__half*)&s_max_bits;
        atomicAdd(out,__half2float(result));
    }
}
