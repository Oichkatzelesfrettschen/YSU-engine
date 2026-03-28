
// Shared atomic exchange (last-writer-wins pattern)
extern "C" __global__ void __launch_bounds__(128)
satom_i32_exch(int *out, const int *in, int n) {
    __shared__ int s_last;
    if(threadIdx.x==0) s_last = 0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int old=atomicExch(&s_last,in[gi]);
        // old contains previous value (can detect ordering)
    }
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s_last;
}
