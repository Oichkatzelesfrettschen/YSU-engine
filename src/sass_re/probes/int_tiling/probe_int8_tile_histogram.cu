
// INT8 histogram (256 bins)
extern "C" __global__ void __launch_bounds__(256)
int8_histogram(unsigned *hist, const unsigned char *in, int n) {
    __shared__ unsigned s[256];
    int tid=threadIdx.x;
    s[tid]=0;
    __syncthreads();
    for(int i=tid+blockIdx.x*blockDim.x;i<n;i+=gridDim.x*blockDim.x)
        atomicAdd(&s[in[i]],1);
    __syncthreads();
    atomicAdd(&hist[tid],s[tid]);
}
