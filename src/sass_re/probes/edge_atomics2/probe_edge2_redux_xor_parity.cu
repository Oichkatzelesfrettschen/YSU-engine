
// Warp-level XOR parity check + shared atomic flag on error
extern "C" __global__ void __launch_bounds__(128)
edge2_parity_check(int *error_flag, const unsigned *data, int n) {
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    unsigned val=(gi<n)?data[gi]:0;
    // Compute per-element parity
    int parity=__popc(val)&1;
    // Warp-level XOR reduction: if result is 0, all parities agree
    int warp_xor; // REDUX.XOR expected here
    asm volatile("redux.sync.xor.b32 %0, %1, 0xffffffff;" : "=r"(warp_xor) : "r"(parity));
    // If any warp has parity error, set flag
    __shared__ int s_error;
    if(threadIdx.x==0) s_error=0;
    __syncthreads();
    if((threadIdx.x&31)==0 && warp_xor!=0) atomicOr(&s_error,1);
    __syncthreads();
    if(threadIdx.x==0 && s_error) atomicOr(error_flag,1);
}
