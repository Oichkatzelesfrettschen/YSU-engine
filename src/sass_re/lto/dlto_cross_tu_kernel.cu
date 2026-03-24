#include "dlto_stage_helpers.cuh"

extern "C" __global__ void __launch_bounds__(32)
probe_dlto_cross_tu(float *out,
                    const float *a_in,
                    const float *b_in,
                    const float *base,
                    int iters,
                    uint64_t stride,
                    int tail_mask,
                    int stage_mask) {
    int lane = threadIdx.x;
    float acc = a_in[lane] + b_in[lane];
    uint64_t byte_off = 0;

    #pragma unroll 1
    for (int t = 0; t < iters; ++t) {
        uint32_t bits = dlto_stage_bits(t, iters, tail_mask, stage_mask);
        byte_off += dlto_byte_bump(t, stride, bits);
        acc = dlto_mix_values(acc, base, lane, bits, byte_off);
        asm volatile("" : "+f"(acc), "+l"(byte_off));
    }

    out[lane] = acc;
}
