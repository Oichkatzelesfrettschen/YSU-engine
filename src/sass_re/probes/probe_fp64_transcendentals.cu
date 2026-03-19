/*
 * SASS RE Probe: FP64 Transcendental Latency Chains
 * Isolates: Dependent chains for FP64 sin/cos/exp/log/sqrt/rsqrt
 *
 * FP64 transcendentals on Ada compile to CALL.REL into libdevice
 * functions (~80-200 instructions each). This probe creates dependent
 * chains to measure the effective per-call latency.
 *
 * From SASS analysis:
 *   sin(double):  ~120 instructions (10 DFMA polynomial)
 *   exp(double):  ~80 instructions
 *   sqrt(double): MUFU.RSQ64H + 10 DFMA Newton-Raphson
 *   log(double):  ~80 instructions
 */

#include <math.h>

// FP64 sin chain
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_sin_chain(volatile double *vals, volatile long long *out) {
    double x = vals[0];
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 64; i++)
        x = sin(x);
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 64; }
}

// FP64 exp chain
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_exp_chain(volatile double *vals, volatile long long *out) {
    double x = vals[0]; // Should be small (e.g., 0.001) to avoid overflow
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 64; i++) {
        x = exp(x);
        x = x * 1e-300; // Keep in range to prevent inf
    }
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 64; }
}

// FP64 log chain
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_log_chain(volatile double *vals, volatile long long *out) {
    double x = vals[0]; // Should be > 0
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 64; i++) {
        x = log(fabs(x) + 1.0); // Keep positive, avoid log(0)
    }
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 64; }
}

// FP64 sqrt chain
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_sqrt_chain(volatile double *vals, volatile long long *out) {
    double x = vals[0];
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 64; i++) {
        x = sqrt(x + 1.0); // +1 keeps it from converging to 1
    }
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 64; }
}

// FP64 rsqrt chain (1/sqrt via MUFU.RSQ64H + Newton-Raphson)
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_rsqrt_chain(volatile double *vals, volatile long long *out) {
    double x = vals[0];
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 64; i++)
        x = rsqrt(x + 1.0);
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 64; }
}

// FP32 fast sin for comparison (single MUFU.SIN)
extern "C" __global__ void __launch_bounds__(32)
probe_fp32_sin_fast_chain(volatile float *vals, volatile long long *out) {
    float x = vals[0];
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll 1
    for (int i = 0; i < 512; i++)
        x = __sinf(x);
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[1] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 512; }
}
