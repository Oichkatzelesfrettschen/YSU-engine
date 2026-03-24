#include "dlto_stage_helpers.cuh"

extern "C" __device__ uint32_t dlto_stage_bits(int t, int iters, int tail_mask, int stage_mask) {
    uint32_t stage = (uint32_t)(t & 1);
    uint32_t wrap = (uint32_t)(((t & 3) == 3) ? 1 : 0);
    uint32_t tail = (uint32_t)(((t + 1) >= iters) ? 1 : 0);
    uint32_t mask0 = (uint32_t)(tail_mask & 0xff);
    uint32_t mask1 = (uint32_t)(stage_mask & 0xff);
    uint32_t bits = 0;

    asm volatile("lop3.b32 %0, %1, %2, %3, 0xe8;"
                 : "=r"(bits)
                 : "r"(stage ^ mask1), "r"(wrap ^ mask0), "r"(tail | mask1));

    bits ^= ((mask0 << 8) | (mask1 << 16));
    bits ^= (stage << 24);
    return bits;
}
