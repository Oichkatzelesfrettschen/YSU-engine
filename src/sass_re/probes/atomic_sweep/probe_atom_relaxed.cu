
// Global atomic without explicit ordering (compiler chooses)
extern "C" __global__ void __launch_bounds__(128)
atom_relaxed_add(int *counter, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAdd(counter, in[gi]); // May generate ATOM.E.ADD (no STRONG?)
}

extern "C" __global__ void __launch_bounds__(128)
atom_relaxed_min(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMin(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_relaxed_max(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMax(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_relaxed_unsigned_min(unsigned *result, const unsigned *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMin(result, in[gi]); // ATOM.E.MIN.U32?
}

extern "C" __global__ void __launch_bounds__(128)
atom_relaxed_unsigned_max(unsigned *result, const unsigned *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMax(result, in[gi]); // ATOM.E.MAX.U32?
}
