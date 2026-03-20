
// Shared atomic UINT32 add (unsigned variant)
extern "C" __global__ void __launch_bounds__(256)
satom_u32_add(unsigned *out, const unsigned *in, int n) {
    __shared__ unsigned s_count[64];
    int tid=threadIdx.x;
    if(tid<64) s_count[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n) atomicAdd(&s_count[in[gi]%64],1u);
    __syncthreads();
    if(tid<64) atomicAdd(&out[tid],s_count[tid]);
}
