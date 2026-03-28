
// Shared atomic latency comparison across types
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_i32(volatile long long *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_u32(volatile long long *out) {
    __shared__ unsigned s; if(threadIdx.x==0)s=0; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1u);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_f32(volatile long long *out) {
    __shared__ float s; if(threadIdx.x==0)s=0.0f; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1.0f);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_i64(volatile long long *out) {
    __shared__ unsigned long long s; if(threadIdx.x==0)s=0; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicAdd(&s,1ULL);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_min(volatile long long *out) {
    __shared__ int s; if(threadIdx.x==0)s=0x7FFFFFFF; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++) atomicMin(&s,j);
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
extern "C" __global__ void __launch_bounds__(32)
atoms_lat_cas(volatile long long *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    long long t0,t1;
    if(threadIdx.x==0){
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
        for(int j=0;j<4096;j++){int old=s;atomicCAS(&s,old,old+1);}
        asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
        out[0]=t1-t0; out[1]=4096;
    }
}
