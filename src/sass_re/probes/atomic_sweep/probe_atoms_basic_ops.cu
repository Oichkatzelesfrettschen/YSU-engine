
// All basic shared memory atomic operations
extern "C" __global__ void __launch_bounds__(128)
atoms_all_ops(int *out, const int *in, int n) {
    __shared__ int s_add, s_min, s_max, s_and, s_or, s_xor, s_exch;
    int tid = threadIdx.x;
    if(tid == 0) { s_add=0; s_min=0x7FFFFFFF; s_max=0x80000000; s_and=0xFFFFFFFF; s_or=0; s_xor=0; s_exch=0; }
    __syncthreads();
    int gi = blockIdx.x*blockDim.x+tid;
    if(gi<n) {
        int v = in[gi];
        atomicAdd(&s_add, v);       // ATOMS.ADD
        atomicMin(&s_min, v);       // ATOMS.MIN
        atomicMax(&s_max, v);       // ATOMS.MAX
        atomicAnd(&s_and, v);       // ATOMS.AND
        atomicOr(&s_or, v);        // ATOMS.OR
        atomicXor(&s_xor, v);      // ATOMS.XOR
    }
    __syncthreads();
    if(tid == 0) { out[blockIdx.x*6]=s_add; out[blockIdx.x*6+1]=s_min; out[blockIdx.x*6+2]=s_max;
                   out[blockIdx.x*6+3]=s_and; out[blockIdx.x*6+4]=s_or; out[blockIdx.x*6+5]=s_xor; }
}
