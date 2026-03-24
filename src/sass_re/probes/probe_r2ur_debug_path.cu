#include <stdint.h>

static __device__ __forceinline__ int r2ur_idx(int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    return i < n ? i : -1;
}

extern "C" __global__ void __launch_bounds__(128)
probe_r2ur_debug_load_store(float *out, const float *in, int n) {
    int i = r2ur_idx(n);
    if (i < 0) return;

    float v = in[i];
    out[i] = v * 2.0f + 1.0f;
}

extern "C" __global__ void __launch_bounds__(128)
probe_r2ur_debug_dual_pointer(float *out0, float *out1,
                              const float *in0, const float *in1,
                              int n, int stride) {
    int i = r2ur_idx(n);
    if (i < 0) return;

    int j = i * stride;
    float a = in0[j];
    float b = in1[j];
    out0[j] = a + b;
    out1[j] = a - b;
}

extern "C" __global__ void __launch_bounds__(128)
probe_r2ur_debug_vector_store(float4 *out, const float4 *in, int n) {
    int i = r2ur_idx(n);
    if (i < 0) return;

    float4 v = in[i];
    v.x += 1.0f;
    v.y *= 2.0f;
    v.z -= 3.0f;
    v.w = -v.w;
    out[i] = v;
}
