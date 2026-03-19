/*
 * SASS RE Probe: FP32 Special Modes (FTZ, SAT, Denormals)
 * Isolates: FFMA.FTZ, FADD.FTZ, FMUL.SAT, denormal handling cost
 *
 * FTZ (Flush To Zero): denormalized results are flushed to zero.
 *   This avoids the ~10x penalty for denormal arithmetic on some GPUs.
 *   On Ada, FP32 operations default to FTZ=false (IEEE compliant).
 *   --use_fast_math enables FTZ globally.
 *
 * SAT (Saturate): clamp result to [0.0, 1.0] range.
 *   Used for color/alpha computation, probability clamping.
 *   Free when combined with FADD/FMUL (no extra instruction).
 *
 * Key SASS:
 *   FFMA        -- default (IEEE, no FTZ)
 *   FFMA.FTZ    -- flush-to-zero mode
 *   FADD.FTZ    -- FTZ add
 *   FMUL.SAT    -- saturate to [0,1]
 *   FADD.SAT    -- saturate add
 */

// Default IEEE mode (no FTZ, handles denormals)
extern "C" __global__ void __launch_bounds__(32)
probe_fp32_ieee(float *out, const float *in) {
    int i = threadIdx.x;
    float x = in[i];
    // Denormal input: 1.0e-40f (below FP32 normal range ~1.18e-38)
    float denorm = 1.0e-40f;
    float result = x * denorm;  // FMUL (IEEE, preserves denormal)
    result = result + denorm;    // FADD (IEEE)
    out[i] = result;
}

// FTZ mode via __fmul_rz / inline asm
extern "C" __global__ void __launch_bounds__(32)
probe_fp32_ftz(float *out, const float *in) {
    int i = threadIdx.x;
    float x = in[i];
    float denorm = 1.0e-40f;
    float result;

    // FMUL.FTZ: flush denormal result to zero
    asm volatile("mul.ftz.f32 %0, %1, %2;" : "=f"(result) : "f"(x), "f"(denorm));
    // FADD.FTZ
    asm volatile("add.ftz.f32 %0, %0, %1;" : "+f"(result) : "f"(denorm));
    out[i] = result;
}

// Saturate mode
extern "C" __global__ void __launch_bounds__(32)
probe_fp32_saturate(float *out, const float *in) {
    int i = threadIdx.x;
    float x = in[i];

    // FMUL.SAT: result clamped to [0.0, 1.0]
    float sat_mul;
    asm volatile("mul.sat.f32 %0, %1, %2;" : "=f"(sat_mul) : "f"(x), "f"(x));

    // FADD.SAT
    float sat_add;
    asm volatile("add.sat.f32 %0, %1, %2;" : "=f"(sat_add) : "f"(x), "f"(0.5f));

    out[i] = sat_mul + sat_add;
}

// FTZ latency chain (compare with IEEE FFMA latency of 4.53 cy)
extern "C" __global__ void __launch_bounds__(32)
probe_fp32_ftz_chain(volatile float *vals, volatile long long *out) {
    float x = vals[0], y = vals[1], z = vals[2];
    long long t0, t1;
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t0));
    #pragma unroll
    for (int i = 0; i < 512; i++)
        asm volatile("fma.rn.ftz.f32 %0, %0, %1, %2;" : "+f"(x) : "f"(y), "f"(z));
    asm volatile("mov.u64 %0, %%clock64;" : "=l"(t1));
    vals[3] = x;
    if (threadIdx.x == 0) { out[0] = t1 - t0; out[1] = 512; }
}

// Denormal throughput test: how much slower are denormal inputs?
extern "C" __global__ void __launch_bounds__(128)
probe_fp32_denormal_cost(float *out, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    // Start with denormal value
    float x = 1.0e-40f;
    #pragma unroll 1
    for (int j = 0; j < 1000; j++)
        x = x * 1.0000001f + 1.0e-45f;  // Keep in denormal range

    out[i] = x;
}

// Normal throughput test (same ops, normal range)
extern "C" __global__ void __launch_bounds__(128)
probe_fp32_normal_cost(float *out, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;

    float x = 1.0f;
    #pragma unroll 1
    for (int j = 0; j < 1000; j++)
        x = x * 1.0000001f + 1.0e-7f;  // Stay in normal range

    out[i] = x;
}
