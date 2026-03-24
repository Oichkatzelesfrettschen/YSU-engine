#include "dlto_stage_helpers.cuh"

extern "C" __device__ uint64_t dlto_byte_bump(int t, uint64_t stride, uint32_t bits) {
    uint64_t step = ((uint64_t)(((bits >> (t & 7)) & 0x3u) + 1u)) * stride;
    uint64_t skew = ((uint64_t)((bits >> 8) & 0xfu)) << 2;
    return step + skew;
}

extern "C" __device__ float dlto_mix_values(float acc,
                                            const float *base,
                                            int lane,
                                            uint32_t bits,
                                            uint64_t byte_off) {
    const char *ptr = (const char *)base + byte_off;
    const float *fptr = (const float *)(ptr + ((size_t)(lane & 3) << 2));
    float x = fptr[0];
    float y = fptr[32];

    if (bits & 0x1u) {
        acc += x;
    } else {
        acc -= x * 0.5f;
    }
    if (bits & 0x100u) {
        acc += y * 2.0f;
    } else {
        acc += y;
    }
    return acc;
}
