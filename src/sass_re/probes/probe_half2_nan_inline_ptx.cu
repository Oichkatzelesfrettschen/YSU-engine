/*
 * SASS RE Probe: half2 NaN-aware min/max through inline PTX
 *
 * cuDNN library mining surfaced HMNMX2.NAN. This probe directly forces the
 * PTX NaN-aware half2 min/max forms to test whether Ada emits that suffix.
 */

#include <cuda_runtime.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_half2_min_nan(uint32_t *out, const uint32_t *a, const uint32_t *b) {
    int i = threadIdx.x;
    uint32_t va = a[i];
    uint32_t vb = b[i];
    uint32_t vd = 0;
    asm volatile("min.NaN.f16x2 %0, %1, %2;"
                 : "=r"(vd)
                 : "r"(va), "r"(vb));
    out[i] = vd;
}

extern "C" __global__ void __launch_bounds__(32)
probe_half2_max_nan(uint32_t *out, const uint32_t *a, const uint32_t *b) {
    int i = threadIdx.x;
    uint32_t va = a[i];
    uint32_t vb = b[i];
    uint32_t vd = 0;
    asm volatile("max.NaN.f16x2 %0, %1, %2;"
                 : "=r"(vd)
                 : "r"(va), "r"(vb));
    out[i] = vd;
}
