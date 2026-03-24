/*
 * SASS RE Probe: F2FP alias-pack follow-up
 *
 * Library-mined cuDNN cubins surfaced shorter spellings:
 *   F2FP.PACK_AB
 *   F2FP.BF16.PACK_AB
 *
 * Direct local sm_89 probes already confirm:
 *   F2FP.F16.F32.PACK_AB
 *   F2FP.BF16.F32.PACK_AB
 *
 * This follow-up tries to mimic the shorter-alias context more closely:
 * pack a single scalar with a compile-time zero lane and immediately store
 * the low 16 bits, plus one paired packed-store control for each format.
 */

#include <cuda_bf16.h>
#include <cuda_fp16.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_f2fp_f16_low_store(uint16_t *out, const float *a) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.f16x2.f32 %0, 0f00000000, %1;"
                 : "=r"(packed)
                 : "f"(a[i]));
    out[i] = static_cast<uint16_t>(packed & 0xffffu);
}

extern "C" __global__ void __launch_bounds__(32)
probe_f2fp_bf16_low_store(uint16_t *out, const float *a) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.bf16x2.f32 %0, 0f00000000, %1;"
                 : "=r"(packed)
                 : "f"(a[i]));
    out[i] = static_cast<uint16_t>(packed & 0xffffu);
}

extern "C" __global__ void __launch_bounds__(32)
probe_f2fp_f16_pair_store(uint32_t *out, const float *a, const float *b) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.f16x2.f32 %0, %1, %2;"
                 : "=r"(packed)
                 : "f"(a[i]), "f"(b[i]));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_f2fp_bf16_pair_store(uint32_t *out, const float *a, const float *b) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.bf16x2.f32 %0, %1, %2;"
                 : "=r"(packed)
                 : "f"(a[i]), "f"(b[i]));
    out[i] = packed;
}
