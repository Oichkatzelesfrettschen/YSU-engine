
// TF32-precision shared atomic: truncate to 19 bits, FMA, atomicAdd
extern "C" __global__ void __launch_bounds__(128)
edge_tf32_fma_accum(float *out, const float *a, const float *b, int n) {
    __shared__ float s_acc;
    if(threadIdx.x==0) s_acc=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        // Truncate inputs to TF32 (zero lower 13 mantissa bits)
        unsigned ba=__float_as_uint(a[gi])&0xFFFFE000u;
        unsigned bb=__float_as_uint(b[gi])&0xFFFFE000u;
        float ta=__uint_as_float(ba), tb=__uint_as_float(bb);
        float result=ta*tb; // TF32-precision multiply
        atomicAdd(&s_acc,result);
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_acc);
}
