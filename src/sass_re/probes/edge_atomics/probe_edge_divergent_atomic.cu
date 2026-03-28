
// Each lane atomicAdds to a DIFFERENT shared memory address (zero contention)
// vs all lanes to SAME address (max contention) -- measures contention scaling
extern "C" __global__ void __launch_bounds__(32)
edge_zero_contention(volatile long long *out) {
    __shared__ int bins[32];
    bins[threadIdx.x]=0;
    __syncthreads();
    long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    for(int j=0;j<4096;j++) atomicAdd(&bins[threadIdx.x],1); // Zero contention
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=4096;}
}

extern "C" __global__ void __launch_bounds__(32)
edge_max_contention(volatile long long *out) {
    __shared__ int bin;
    if(threadIdx.x==0) bin=0;
    __syncthreads();
    long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    for(int j=0;j<4096;j++) atomicAdd(&bin,1); // 32-way contention
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=4096;}
}
