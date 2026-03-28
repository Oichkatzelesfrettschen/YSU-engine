
// INT4 histogram: count occurrences of each nibble value (16 bins)
extern "C" __global__ void __launch_bounds__(256)
int4_tile_histogram(unsigned int *hist, const unsigned char *in, int n) {
    __shared__ unsigned int s_hist[16];
    int tid=threadIdx.x;
    if(tid<16) s_hist[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n){
        atomicAdd(&s_hist[in[gi]&0xF],1);
        atomicAdd(&s_hist[(in[gi]>>4)&0xF],1);
    }
    __syncthreads();
    if(tid<16) atomicAdd(&hist[tid],s_hist[tid]);
}
