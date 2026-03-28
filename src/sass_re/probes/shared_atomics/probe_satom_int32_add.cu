
// Shared atomic INT32 add: histogram pattern (most common)
extern "C" __global__ void __launch_bounds__(256)
satom_i32_add(int *out, const int *in, int n, int n_bins) {
    __shared__ int s_hist[256];
    int tid=threadIdx.x;
    s_hist[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n) atomicAdd(&s_hist[in[gi]%n_bins],1);
    __syncthreads();
    atomicAdd(&out[tid],s_hist[tid]);
}
