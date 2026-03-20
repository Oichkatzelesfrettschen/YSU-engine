
// INT32 radix sort digit extraction (4-bit radix)
extern "C" __global__ void __launch_bounds__(256)
int32_radix_digit(int *digit_count, const int *in, int n, int bit_offset) {
    __shared__ int s_count[16];
    int tid=threadIdx.x;
    if(tid<16) s_count[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*256+tid;
    if(gi<n){
        int digit=(in[gi]>>bit_offset)&0xF;
        atomicAdd(&s_count[digit],1);
    }
    __syncthreads();
    if(tid<16) atomicAdd(&digit_count[blockIdx.x*16+tid],s_count[tid]);
}
