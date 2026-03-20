
// FP4 E2M1 histogram: count which of 16 FP4 values occurs most
// Atomic increment on smem histogram bins, indexed by nibble value
extern "C" __global__ void __launch_bounds__(256)
edge2_fp4_hist(unsigned *hist, const unsigned char *packed, int n_bytes) {
    __shared__ unsigned s_hist[16];
    int tid=threadIdx.x;
    if(tid<16) s_hist[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n_bytes){
        unsigned char b=packed[gi];
        atomicAdd(&s_hist[b&0xF],1);
        atomicAdd(&s_hist[(b>>4)&0xF],1);
    }
    __syncthreads();
    if(tid<16) atomicAdd(&hist[tid],s_hist[tid]);
}
