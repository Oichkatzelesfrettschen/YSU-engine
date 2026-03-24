/*
 * SASS RE Probe: IDP.4A signedness variants
 *
 * Forces the four packed INT8 dot-product signedness combinations through
 * inline PTX so cuobjdump can confirm the exact emitted IDP.4A suffixes:
 *   - IDP.4A.U8.U8
 *   - IDP.4A.S8.S8
 *   - IDP.4A.S8.U8
 *   - IDP.4A.U8.S8
 *
 * The inputs are already host-packed into 32-bit words before launch. This
 * avoids polluting the kernel SASS with BFE/SHF/PRMT packing instructions.
 */

#include <stdint.h>

extern "C" __global__ void __launch_bounds__(32)
probe_dp4a_u8_u8(int *out, const uint32_t *a, const uint32_t *b) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t va = a[idx];
    uint32_t vb = b[idx];
    int acc = 0;
    asm volatile("dp4a.u32.u32 %0, %1, %2, %3;" : "=r"(acc) : "r"(va), "r"(vb), "r"(acc));
    out[idx] = acc;
}

extern "C" __global__ void __launch_bounds__(32)
probe_dp4a_s8_s8(int *out, const uint32_t *a, const uint32_t *b) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t va = a[idx];
    uint32_t vb = b[idx];
    int acc = 0;
    asm volatile("dp4a.s32.s32 %0, %1, %2, %3;" : "=r"(acc) : "r"(va), "r"(vb), "r"(acc));
    out[idx] = acc;
}

extern "C" __global__ void __launch_bounds__(32)
probe_dp4a_s8_u8(int *out, const uint32_t *a, const uint32_t *b) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t va = a[idx];
    uint32_t vb = b[idx];
    int acc = 0;
    asm volatile("dp4a.s32.u32 %0, %1, %2, %3;" : "=r"(acc) : "r"(va), "r"(vb), "r"(acc));
    out[idx] = acc;
}

extern "C" __global__ void __launch_bounds__(32)
probe_dp4a_u8_s8(int *out, const uint32_t *a, const uint32_t *b) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t va = a[idx];
    uint32_t vb = b[idx];
    int acc = 0;
    asm volatile("dp4a.u32.s32 %0, %1, %2, %3;" : "=r"(acc) : "r"(va), "r"(vb), "r"(acc));
    out[idx] = acc;
}
