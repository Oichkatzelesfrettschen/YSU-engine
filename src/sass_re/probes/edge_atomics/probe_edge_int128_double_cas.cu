
// INT128 atomic increment via two 64-bit CAS operations (carry chain)
extern "C" __global__ void __launch_bounds__(128)
edge_i128_cas(unsigned long long *out_lo, unsigned long long *out_hi, int iters) {
    __shared__ unsigned long long s_lo, s_hi;
    if(threadIdx.x==0){s_lo=0;s_hi=0;}
    __syncthreads();
    for(int j=0;j<iters;j++){
        // Atomically increment 128-bit counter
        unsigned long long old_lo=atomicAdd(&s_lo,1ULL);
        if(old_lo==0xFFFFFFFFFFFFFFFFULL) atomicAdd(&s_hi,1ULL); // Carry
    }
    __syncthreads();
    if(threadIdx.x==0){*out_lo=s_lo;*out_hi=s_hi;}
}
