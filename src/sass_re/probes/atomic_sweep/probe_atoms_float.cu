
// Shared atomic float add (all contention levels)
extern "C" __global__ void __launch_bounds__(128)
atoms_float_add(float *out, const float *in, int n) {
    __shared__ float s_sum;
    if(threadIdx.x == 0) s_sum = 0.0f;
    __syncthreads();
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(&s_sum, in[gi]); // ATOMS.ADD.F32?
    __syncthreads();
    if(threadIdx.x == 0) atomicAdd(out, s_sum);
}
