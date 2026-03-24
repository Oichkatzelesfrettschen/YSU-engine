/*
 * SASS RE Probe: scalar F2FP alias pack follow-up
 *
 * cuDNN library mining surfaced shorter spellings:
 *   - F2FP.PACK_AB
 *   - F2FP.BF16.PACK_AB
 *
 * Existing direct local probes already confirm the typed x2 forms:
 *   - F2FP.F16.F32.PACK_AB
 *   - F2FP.BF16.F32.PACK_AB
 *   - F2FP.RELU.BF16.F32.PACK_AB
 *
 * The library-mined context strongly suggests the shorter aliases may come
 * from one-source scalar convert + pack/store lowering rather than the explicit
 * two-source x2 convert path. This file targets that narrower shape.
 */

#include <cuda_bf16.h>
#include <cuda_fp16.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_f16_scalar_store(__half *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    out[i] = __float2half_rn(x);
}

extern "C" __global__ void __launch_bounds__(32)
probe_f16_scalar_pack_lo(uint32_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint32_t packed = 0;
    asm volatile(
        "{\n\t"
        "  .reg .b16 h0, hz;\n\t"
        "  cvt.rn.f16.f32 h0, %1;\n\t"
        "  mov.b16 hz, 0;\n\t"
        "  mov.b32 %0, {h0, hz};\n\t"
        "}\n"
        : "=r"(packed)
        : "f"(x));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_f16_scalar_pack_hi(uint32_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint32_t packed = 0;
    asm volatile(
        "{\n\t"
        "  .reg .b16 h0, hz;\n\t"
        "  cvt.rn.f16.f32 h0, %1;\n\t"
        "  mov.b16 hz, 0;\n\t"
        "  mov.b32 %0, {hz, h0};\n\t"
        "}\n"
        : "=r"(packed)
        : "f"(x));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_scalar_store(__nv_bfloat16 *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    out[i] = __float2bfloat16(x);
}

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_scalar_pack_lo(uint32_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint32_t packed = 0;
    asm volatile(
        "{\n\t"
        "  .reg .b16 b0, bz;\n\t"
        "  cvt.rn.bf16.f32 b0, %1;\n\t"
        "  mov.b16 bz, 0;\n\t"
        "  mov.b32 %0, {b0, bz};\n\t"
        "}\n"
        : "=r"(packed)
        : "f"(x));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_scalar_pack_lo_relu(uint32_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint32_t packed = 0;
    asm volatile(
        "{\n\t"
        "  .reg .b16 b0, bz;\n\t"
        "  cvt.rn.relu.bf16.f32 b0, %1;\n\t"
        "  mov.b16 bz, 0;\n\t"
        "  mov.b32 %0, {b0, bz};\n\t"
        "}\n"
        : "=r"(packed)
        : "f"(x));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_f16_scalar_u16_store(uint16_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint16_t bits = 0;
    asm volatile("cvt.rn.f16.f32 %0, %1;" : "=h"(bits) : "f"(x));
    out[i] = bits;
}

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_scalar_u16_store(uint16_t *out, const float *in, float scale, float bias) {
    int i = threadIdx.x;
    float x = fmaf(in[i], scale, bias);
    uint16_t bits = 0;
    asm volatile("cvt.rn.bf16.f32 %0, %1;" : "=h"(bits) : "f"(x));
    out[i] = bits;
}
