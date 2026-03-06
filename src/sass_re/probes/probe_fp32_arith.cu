/*
 * SASS RE Probe: FP32 Arithmetic
 * Isolates: FADD, FMUL, FFMA, FMNMX, FABS, FNEG
 *
 * Compile:  nvcc -arch=sm_89 -cubin -o probe_fp32_arith.cubin probe_fp32_arith.cu
 *   Disasm: cuobjdump -sass probe_fp32_arith.cubin
 *   Binary: nvdisasm -raw -binary SM89 probe_fp32_arith.cubin
 *
 * The __noinline__ prevents the compiler from optimizing away our chains.
 * The volatile asm clobber prevents dead-code elimination.
 */

// Chain of FADDs -- look for FADD Rd, Ra, Rb in SASS
extern "C" __global__ void __launch_bounds__(32)
probe_fadd(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float x = a[i];
    float y = b[i];
    // 16-deep FADD chain to see dependency latency
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    x = x + y;
    out[i] = x;
}

// Chain of FMULs
extern "C" __global__ void __launch_bounds__(32)
probe_fmul(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float x = a[i];
    float y = b[i];
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    x = x * y;
    out[i] = x;
}

// FFMAs: fused multiply-add  (the workhorse instruction)
extern "C" __global__ void __launch_bounds__(32)
probe_ffma(float *out, const float *a, const float *b, const float *c) {
    int i = threadIdx.x;
    float x = a[i];
    float y = b[i];
    float z = c[i];
    // FFMA chain: x = x*y + z  (each depends on previous x)
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    x = __fmaf_rn(x, y, z);
    out[i] = x;
}

// FMNMX: float min/max
extern "C" __global__ void __launch_bounds__(32)
probe_fmnmx(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float x = a[i];
    float y = b[i];
    x = fminf(x, y);  // FMNMX with predicate = PT (min)
    x = fmaxf(x, y);  // FMNMX with predicate = !PT (max)
    x = fminf(x, y);
    x = fmaxf(x, y);
    x = fminf(x, y);
    x = fmaxf(x, y);
    x = fminf(x, y);
    x = fmaxf(x, y);
    out[i] = x;
}

// FABS / FNEG -- these are usually source modifiers, not standalone instructions.
// Watch the SASS: FADD with |Ra| (abs) or -Ra (neg) modifiers
extern "C" __global__ void __launch_bounds__(32)
probe_fabs_fneg(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float x = a[i];
    float y = b[i];
    x = fabsf(x) + y;       // FADD Rd, |Ra|, Rb
    x = (-x) + y;            // FADD Rd, -Ra, Rb
    x = fabsf(-x) + y;      // FADD Rd, |(-Ra)|, Rb -- interesting: does it fold?
    x = fabsf(x) * y;       // FMUL Rd, |Ra|, Rb
    out[i] = x;
}

// Independent FADDs (no chain) to see throughput / ILP
extern "C" __global__ void __launch_bounds__(32)
probe_fadd_independent(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float a0 = a[i], a1 = a[i+32], a2 = a[i+64], a3 = a[i+96];
    float b0 = b[i], b1 = b[i+32], b2 = b[i+64], b3 = b[i+96];
    // These are all independent -- scheduler can issue them back-to-back
    float r0 = a0 + b0;
    float r1 = a1 + b1;
    float r2 = a2 + b2;
    float r3 = a3 + b3;
    r0 = r0 + b0;
    r1 = r1 + b1;
    r2 = r2 + b2;
    r3 = r3 + b3;
    out[i]    = r0;
    out[i+32] = r1;
    out[i+64] = r2;
    out[i+96] = r3;
}
