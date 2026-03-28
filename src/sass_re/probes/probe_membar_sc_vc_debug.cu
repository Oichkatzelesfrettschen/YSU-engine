#include <stdint.h>

extern "C" __global__ void __launch_bounds__(128)
probe_membar_sc_vc_store(int *out, const int *in, int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    if (i >= n) return;

    int v = in[i];
    out[i] = v + 1;
}

extern "C" __global__ void __launch_bounds__(128)
probe_membar_sc_vc_volatile_store(volatile int *out, const volatile int *in, int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    if (i >= n) return;

    int v = in[i];
    out[i] = v ^ 0x5a5a5a5a;
}

extern "C" __global__ void __launch_bounds__(128)
probe_membar_sc_vc_fence_compare(volatile int *flag, volatile int *data, int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    if (i >= n) return;

    data[i] = i;
    __threadfence();
    flag[i] = 1;
}

extern "C" __global__ void __launch_bounds__(128)
probe_membar_sc_vc_system_compare(volatile int *flag, volatile int *data, int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    if (i >= n) return;

    data[i] = i;
    __threadfence_system();
    flag[i] = 1;
}
