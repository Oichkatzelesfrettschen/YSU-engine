/*
 * SASS RE Probe: MUFU (Multi-Function Unit) -- Special Function Unit (SFU)
 * Isolates: MUFU.RCP, MUFU.RSQ, MUFU.SIN, MUFU.COS, MUFU.EX2, MUFU.LG2,
 *           MUFU.RCP64H, MUFU.RSQ64H
 *
 * The SFU has only 1 pipeline per sub-partition (vs 2 FP32 pipelines),
 * so throughput is 16 ops/clock per SM sub-partition.
 * Latency is typically ~4 cycles.
 *
 * These are fast approximations (not IEEE-accurate).
 * The compiler generates multi-instruction sequences for full-precision math.
 * We use __intrinsics to force single MUFU instructions.
 */

// MUFU.RCP -- fast reciprocal
extern "C" __global__ void __launch_bounds__(32)
probe_mufu_rcp(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];
    x = __frcp_rn(x);  // MUFU.RCP
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    x = __frcp_rn(x);
    out[i] = x;
}

// MUFU.RSQ -- fast reciprocal square root
extern "C" __global__ void __launch_bounds__(32)
probe_mufu_rsq(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];
    x = __frsqrt_rn(x);  // MUFU.RSQ
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    x = __frsqrt_rn(x);
    out[i] = x;
}

// MUFU.SIN / MUFU.COS -- fast trig
extern "C" __global__ void __launch_bounds__(32)
probe_mufu_sincos(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];
    float s, c;
    // __sinf / __cosf use MUFU.SIN / MUFU.COS directly
    s = __sinf(x);
    c = __cosf(x);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    s = __sinf(s + c);
    c = __cosf(s + c);
    out[i] = s + c;
}

// MUFU.EX2 / MUFU.LG2 -- fast exp2 / log2
extern "C" __global__ void __launch_bounds__(32)
probe_mufu_ex2_lg2(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];
    x = __expf(x);    // internally: MUFU.EX2(x * LOG2E)
    x = __logf(x);    // internally: MUFU.LG2(x) * LN2
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    x = __expf(x);
    x = __logf(x);
    out[i] = x;
}

// MUFU.SQRT -- fast square root (Ada Lovelace added this)
extern "C" __global__ void __launch_bounds__(32)
probe_mufu_sqrt(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];
    // sqrtf may compile to IEEE-accurate sequence. Use fast math:
    #pragma unroll
    for (int j = 0; j < 16; j++) {
        x = __fsqrt_rn(x + 1.0f);
    }
    out[i] = x;
}
