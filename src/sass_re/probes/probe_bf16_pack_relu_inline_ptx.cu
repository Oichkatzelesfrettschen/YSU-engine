/*
 * SASS RE Probe: packed BF16 convert through inline PTX
 *
 * cuDNN library mining surfaced F2FP.BF16.PACK_AB. Existing direct probes
 * already confirm F2FP.BF16.F32.PACK_AB. This probe forces packed bf16x2
 * conversion, including the relu form, to see whether Ada emits the shorter
 * library-mined spelling locally on sm_89.
 */

#include <cuda_runtime.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_pack(uint32_t *out, const float *a, const float *b) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.bf16x2.f32 %0, %1, %2;"
                 : "=r"(packed)
                 : "f"(a[i]), "f"(b[i]));
    out[i] = packed;
}

extern "C" __global__ void __launch_bounds__(32)
probe_bf16_pack_relu(uint32_t *out, const float *a, const float *b) {
    int i = threadIdx.x;
    uint32_t packed = 0;
    asm volatile("cvt.rn.relu.bf16x2.f32 %0, %1, %2;"
                 : "=r"(packed)
                 : "f"(a[i]), "f"(b[i]));
    out[i] = packed;
}
