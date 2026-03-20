
#include <cuda_bf16.h>
// BF16 histogram: quantize BF16 values to bins, count in shared mem
extern "C" __global__ void __launch_bounds__(256)
edge_bf16_hist(unsigned *hist, const __nv_bfloat16 *in, int n, int n_bins) {
    __shared__ unsigned s_hist[256];
    int tid=threadIdx.x;
    if(tid<n_bins) s_hist[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n){
        float v=__bfloat162float(in[gi]);
        int bin=(int)((v+1.0f)*0.5f*(float)n_bins); // Map [-1,1] to [0,n_bins)
        bin=max(0,min(n_bins-1,bin));
        atomicAdd(&s_hist[bin],1);
    }
    __syncthreads();
    if(tid<n_bins) atomicAdd(&hist[tid],s_hist[tid]);
}
