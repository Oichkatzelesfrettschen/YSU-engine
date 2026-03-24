/*
 * SASS RE Probe: force packed half2 ReLU FMA through inline PTX
 *
 * cuDNN library mining first surfaced HFMA2.RELU near Ada. This direct probe
 * forces PTX fma.rn.relu.f16x2 so the spelling can be confirmed from a local
 * sm_89 compile.
 */

#include <cuda_runtime.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_half2_fma_relu_once(uint32_t *out,
                          const uint32_t *a,
                          const uint32_t *b,
                          const uint32_t *c) {
    int i = threadIdx.x;
    uint32_t va = a[i];
    uint32_t vb = b[i];
    uint32_t vc = c[i];
    uint32_t vd = 0;
    asm volatile("fma.rn.relu.f16x2 %0, %1, %2, %3;"
                 : "=r"(vd)
                 : "r"(va), "r"(vb), "r"(vc));
    out[i] = vd;
}

extern "C" __global__ void __launch_bounds__(32)
probe_half2_fma_relu_chain(uint32_t *out,
                           const uint32_t *a,
                           const uint32_t *b,
                           const uint32_t *c) {
    int i = threadIdx.x;
    uint32_t acc = c[i];
    uint32_t va = a[i];
    uint32_t vb = b[i];
    #pragma unroll 1
    for (int j = 0; j < 32; ++j) {
        asm volatile("fma.rn.relu.f16x2 %0, %1, %2, %0;"
                     : "+r"(acc)
                     : "r"(va), "r"(vb));
    }
    out[i] = acc;
}
