/*
 * SASS RE Probe: FP64 Extended Operations
 * Isolates: DMNMX (FP64 min/max), DSETP variants, FCHK.DIVIDE
 *
 * Completes FP64 pipeline characterization beyond DADD/DFMA/DMUL.
 * On Ada gaming SKU (64:1 FP64:FP32 ratio), all FP64 ops share the
 * scarce FP64 ALU. This probe determines whether DMNMX and DSETP
 * also stall at ~48 cycles or use a faster comparison path.
 *
 * Key SASS:
 *   DMNMX     -- FP64 min/max select
 *   DSETP     -- FP64 set predicate (comparison)
 *   FCHK      -- float validity check (NaN/Inf/denorm)
 */

// FP64 min/max
extern "C" __global__ void __launch_bounds__(32)
probe_dmnmx(double *out, const double *a, const double *b) {
    int i = threadIdx.x;
    double va = a[i], vb = b[i];

    double mn = fmin(va, vb);   // DMNMX with min predicate
    double mx = fmax(va, vb);   // DMNMX with max predicate
    double ab = fabs(va);       // DMNMX or DMUL by sign

    out[i] = mn + mx + ab;
}

// FP64 comparison chain
extern "C" __global__ void __launch_bounds__(32)
probe_dsetp(double *out, const double *a, const double *b) {
    int i = threadIdx.x;
    double va = a[i], vb = b[i];

    double r = 0.0;
    if (va > vb)  r += 1.0;     // DSETP.GT
    if (va < vb)  r += 2.0;     // DSETP.LT
    if (va == vb) r += 4.0;     // DSETP.EQ
    if (va != vb) r += 8.0;     // DSETP.NE
    if (va >= vb) r += 16.0;    // DSETP.GE
    if (va <= vb) r += 32.0;    // DSETP.LE

    // Unordered comparisons (NaN-aware)
    if (!(va == va)) r += 64.0; // DSETP.NAN (isnan check)

    out[i] = r;
}

// Float validity check (triggers FCHK instruction)
extern "C" __global__ void __launch_bounds__(32)
probe_fchk_divide(float *out, const float *a, const float *b) {
    int i = threadIdx.x;
    float va = a[i], vb = b[i];

    // Division generates FCHK for divide-by-zero guard
    float result = va / vb;

    // isnan/isinf checks may generate FCHK variants
    if (__isnanf(result)) result = 0.0f;
    if (__isinff(result)) result = 1.0f;

    out[i] = result;
}

// FP64 division (generates MUFU.RCP64H + Newton-Raphson + FCHK)
extern "C" __global__ void __launch_bounds__(32)
probe_fp64_divide(double *out, const double *a, const double *b) {
    int i = threadIdx.x;
    out[i] = a[i] / b[i];
}
