
// Shared atomic unsigned operations (UINT32 min/max)
extern "C" __global__ void __launch_bounds__(128)
atoms_unsigned(unsigned *out, const unsigned *in, int n) {
    __shared__ unsigned s_min, s_max, s_add;
    int tid = threadIdx.x;
    if(tid == 0) { s_min = 0xFFFFFFFF; s_max = 0; s_add = 0; }
    __syncthreads();
    int gi = blockIdx.x*blockDim.x+tid;
    if(gi<n) {
        unsigned v = in[gi];
        atomicMin(&s_min, v);   // ATOMS.MIN.U32?
        atomicMax(&s_max, v);   // ATOMS.MAX.U32?
        atomicAdd(&s_add, v);   // ATOMS.ADD.U32?
    }
    __syncthreads();
    if(tid == 0) { out[blockIdx.x*3] = s_min; out[blockIdx.x*3+1] = s_max; out[blockIdx.x*3+2] = s_add; }
}
