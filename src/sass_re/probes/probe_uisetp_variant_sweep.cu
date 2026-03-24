/*
 * SASS RE Probe: unsigned set-predicate variant sweep
 *
 * Goal: directly confirm additional UISETP.* spellings seen in library-mined
 * bundles but not yet promoted into the checked-in direct local inventory.
 */

#include <cuda_runtime.h>
#include <stdint.h>

extern "C" __global__ void __launch_bounds__(128)
probe_uisetp_eq_ne(uint32_t *out, const uint32_t *a, const uint32_t *b) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    uint32_t x = a[i];
    uint32_t y = b[i];

    bool p_eq = (x == y);
    bool p_ne = (x != y);
    bool p_lt = (x < y);
    bool p_ge = (x >= y);

    uint32_t r = 0;
    if (p_eq && p_ge) r ^= 0x11u;
    if (p_eq || p_lt) r ^= 0x22u;
    if (p_ne && p_lt) r ^= 0x44u;
    if (p_ne || p_ge) r ^= 0x88u;
    out[i] = r + x;
}

extern "C" __global__ void __launch_bounds__(128)
probe_uisetp_lt_gt(uint32_t *out, const uint32_t *a, const uint32_t *b) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    uint32_t x = a[i];
    uint32_t y = b[i];

    bool p_gt = (x > y);
    bool p_lt = (x < y);
    bool p_le = (x <= y);
    bool p_ne = (x != y);

    uint32_t r = 0;
    if (p_gt && p_ne) r ^= 0x101u;
    if (p_lt && p_le) r ^= 0x202u;
    if (p_lt || p_ne) r ^= 0x404u;
    if (p_lt && p_ne) r ^= 0x808u;
    out[i] = r + y;
}

extern "C" __global__ void __launch_bounds__(128)
probe_uisetp_ex(uint32_t *out, const uint32_t *a, const uint32_t *b) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    uint32_t x = a[i];
    uint32_t y = b[i];

    bool p0 = (x != y);
    bool p1 = (x <= y);
    bool p2 = (x >= y);

    uint32_t r = 0;
    if ((p0 && p1) ^ p2) r ^= 0x1000u;
    if (p0 && (p1 ^ p2)) r ^= 0x2000u;
    out[i] = r + x + y;
}
