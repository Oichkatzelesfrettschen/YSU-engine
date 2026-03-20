
// FMA-style shared atomic: atomicAdd of FMA result (multiply-accumulate)
extern "C" __global__ void __launch_bounds__(128)
satom_fma_accum(float *out, const float *a, const float *b, const float *c, int n) {
    __shared__ float s_acc;
    if(threadIdx.x==0) s_acc=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float fma_result=fmaf(a[gi],b[gi],c[gi]);
        atomicAdd(&s_acc,fma_result); // FFMA then ATOMS.ADD.F32
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_acc);
}
