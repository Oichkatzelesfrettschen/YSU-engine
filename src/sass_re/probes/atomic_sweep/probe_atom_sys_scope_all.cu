
// System-scope variants for all atomic ops
extern "C" __global__ void __launch_bounds__(128)
atom_sys_min(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMin_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_max(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMax_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_and(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicAnd_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_or(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicOr_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_xor(int *result, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicXor_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_umin(unsigned *result, const unsigned *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMin_system(result, in[gi]);
}

extern "C" __global__ void __launch_bounds__(128)
atom_sys_umax(unsigned *result, const unsigned *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n) atomicMax_system(result, in[gi]);
}
