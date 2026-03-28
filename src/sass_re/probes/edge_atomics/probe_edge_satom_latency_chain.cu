
// Shared atomic latency: single thread doing repeated atomicAdd (pure latency)
extern "C" __global__ void __launch_bounds__(32)
edge_satom_latency(volatile long long *out) {
    __shared__ int s;
    if(threadIdx.x==0) s=0;
    __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}

// Same but float
extern "C" __global__ void __launch_bounds__(32)
edge_satom_f32_latency(volatile long long *out) {
    __shared__ float s;
    if(threadIdx.x==0) s=0.0f;
    __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1.0f);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
