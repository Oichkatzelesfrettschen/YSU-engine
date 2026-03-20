
// Shared atomic INT64 add (unsigned long long)
extern "C" __global__ void __launch_bounds__(128)
satom_i64_add(unsigned long long *out, const unsigned long long *in, int n) {
    __shared__ unsigned long long s_sum;
    if(threadIdx.x==0) s_sum=0ULL;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s_sum,in[gi]);
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
