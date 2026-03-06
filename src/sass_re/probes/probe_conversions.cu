/*
 * SASS RE Probe: Type Conversions
 * Isolates: F2I, I2F, F2F (FP32<->FP16<->FP64), FRND, I2I
 *
 * Conversion instructions often have interesting modifiers:
 *   .TRUNC, .FLOOR, .CEIL, .ROUND for rounding mode
 *   .F32.F16, .F16.F32, .F64.F32 for type pair
 */

#include <cuda_fp16.h>

// F2I: float to int (various rounding modes)
extern "C" __global__ void __launch_bounds__(32)
probe_f2i(int *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];

    int r_trunc  = __float2int_rz(x);  // F2I.TRUNC
    int r_near   = __float2int_rn(x);  // F2I.ROUND
    int r_floor  = __float2int_rd(x);  // F2I.FLOOR
    int r_ceil   = __float2int_ru(x);  // F2I.CEIL

    unsigned u_trunc = __float2uint_rz(x);   // F2I.U32.TRUNC
    unsigned u_near  = __float2uint_rn(x);   // F2I.U32.ROUND

    out[i] = r_trunc + r_near + r_floor + r_ceil + (int)u_trunc + (int)u_near;
}

// I2F: int to float
extern "C" __global__ void __launch_bounds__(32)
probe_i2f(float *out, const int *a) {
    int i = threadIdx.x;
    int x = a[i];

    float r_near = __int2float_rn(x);      // I2F.F32.S32.RN
    float r_trunc = __int2float_rz(x);     // I2F.F32.S32.RZ
    float r_down = __int2float_rd(x);      // I2F.F32.S32.RM
    float r_up = __int2float_ru(x);        // I2F.F32.S32.RP

    float u_near = __uint2float_rn((unsigned)x);  // I2F.F32.U32.RN

    out[i] = r_near + r_trunc + r_down + r_up + u_near;
}

// F2F: float-to-float (width conversion)
extern "C" __global__ void __launch_bounds__(32)
probe_f2f_fp16(float *out, const float *a) {
    int i = threadIdx.x;
    float x = a[i];

    // F32 -> F16 -> F32 round-trip
    // F2F.F16.F32 then F2F.F32.F16
    __half h = __float2half(x);
    float back = __half2float(h);

    // F32 -> F16 with specific rounding
    __half h_rn = __float2half_rn(x);
    __half h_rz = __float2half_rz(x);
    __half h_rd = __float2half_rd(x);
    __half h_ru = __float2half_ru(x);

    out[i] = back + __half2float(h_rn) + __half2float(h_rz)
           + __half2float(h_rd) + __half2float(h_ru);
}

// F2F: FP64 conversions
extern "C" __global__ void __launch_bounds__(32)
probe_f2f_fp64(double *out, const float *a, const double *b) {
    int i = threadIdx.x;
    float x = a[i];
    double d = b[i];

    // F32 -> F64: F2F.F64.F32 (widen)
    double widened = (double)x;

    // F64 -> F32: F2F.F32.F64 (narrow)
    float narrowed = (float)d;

    // F64 arithmetic for comparison (DADD, DMUL)
    double dadd = widened + d;
    double dmul = widened * d;

    out[i] = dadd + dmul + (double)narrowed;
}

// Integer width conversions: I2I
extern "C" __global__ void __launch_bounds__(32)
probe_i2i(int *out, const short *a, const char *b) {
    int i = threadIdx.x;

    // S16 -> S32: sign-extend  (I2I.S32.S16)
    int from_short = (int)a[i];

    // U8 -> U32: zero-extend (I2I.U32.U8)
    // S8 -> S32: sign-extend (I2I.S32.S8)
    int from_char_s = (int)b[i];
    unsigned from_char_u = (unsigned)(unsigned char)b[i];

    // S32 -> S16: truncate (I2I.S16.S32)
    short narrowed = (short)from_short;

    out[i] = from_short + from_char_s + (int)from_char_u + (int)narrowed;
}
