
// Shared atomic contention characterization: 1, 4, 32, 128 threads -> 1 address
extern "C" __global__ void __launch_bounds__(128)
satom_contention_1(int *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    if(threadIdx.x==0) for(int j=0;j<4096;j++) atomicAdd(&s,1);
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s;
}
extern "C" __global__ void __launch_bounds__(128)
satom_contention_4(int *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    if(threadIdx.x<4) for(int j=0;j<4096;j++) atomicAdd(&s,1);
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s;
}
extern "C" __global__ void __launch_bounds__(128)
satom_contention_32(int *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    if(threadIdx.x<32) for(int j=0;j<4096;j++) atomicAdd(&s,1);
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s;
}
extern "C" __global__ void __launch_bounds__(128)
satom_contention_128(int *out) {
    __shared__ int s; if(threadIdx.x==0)s=0; __syncthreads();
    for(int j=0;j<4096;j++) atomicAdd(&s,1);
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s;
}
