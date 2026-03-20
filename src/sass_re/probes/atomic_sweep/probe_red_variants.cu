
// RED.E variants: reduction (no return value, potentially faster than ATOM)
// These use the "fire-and-forget" reduction path
extern "C" __global__ void __launch_bounds__(128)
red_add_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    // Use inline PTX to force RED instead of ATOM
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.add.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_min_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.min.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_max_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.max.s32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_and_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.and.b32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_or_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.or.b32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_xor_int(int *target, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val = in[gi];
        asm volatile("red.global.xor.b32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_add_u64(unsigned long long *target, const unsigned long long *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        unsigned long long val = in[gi];
        asm volatile("red.global.add.u64 [%0], %1;" :: "l"(target), "l"(val) : "memory");
    }
}

extern "C" __global__ void __launch_bounds__(128)
red_min_u32(unsigned *target, const unsigned *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        unsigned val = in[gi];
        asm volatile("red.global.min.u32 [%0], %1;" :: "l"(target), "r"(val) : "memory");
    }
}
