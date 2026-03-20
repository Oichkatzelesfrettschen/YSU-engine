
#include <cuda_fp8.h>
#include <cuda_fp16.h>
// MXFP8 dot product: 32-element blocks share scale, dot with weights, atomic sum
extern "C" __global__ void __launch_bounds__(128)
edge2_mxfp8_dot(float *out, const __nv_fp8_storage_t *elems, const unsigned char *scales,
                const float *weights, int n_blocks) {
    __shared__ float s_dot;
    if(threadIdx.x==0) s_dot=0.0f;
    __syncthreads();
    int block_id=(blockIdx.x*blockDim.x+threadIdx.x)/32;
    int elem_in_block=(blockIdx.x*blockDim.x+threadIdx.x)%32;
    if(block_id<n_blocks){
        unsigned int sb=((unsigned int)scales[block_id])<<23;
        float scale=__int_as_float(sb);
        __half_raw hr=__nv_cvt_fp8_to_halfraw(elems[block_id*32+elem_in_block],__NV_E4M3);
        __half h; __builtin_memcpy(&h,&hr,sizeof(h));
        float val=__half2float(h)*scale;
        float w=weights[block_id*32+elem_in_block];
        atomicAdd(&s_dot,val*w);
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_dot);
}
