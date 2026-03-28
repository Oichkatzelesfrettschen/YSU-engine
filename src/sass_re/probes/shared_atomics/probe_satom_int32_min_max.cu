
// Shared atomic INT32 min+max (simultaneous)
extern "C" __global__ void __launch_bounds__(256)
satom_i32_minmax(int *g_min, int *g_max, const int *in, int n) {
    __shared__ int s_min, s_max;
    if(threadIdx.x==0){s_min=0x7FFFFFFF;s_max=0x80000000;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        atomicMin(&s_min,in[gi]);
        atomicMax(&s_max,in[gi]);
    }
    __syncthreads();
    if(threadIdx.x==0){atomicMin(g_min,s_min);atomicMax(g_max,s_max);}
}
