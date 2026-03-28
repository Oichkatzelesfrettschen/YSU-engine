
// System-scope RED variants
extern "C" __global__ void __launch_bounds__(128)
red_sys_add(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.sys.add.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_sys_min(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.sys.min.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_sys_max(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.sys.max.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}
