#pragma once

#include <cuda_runtime.h>
#include <stdint.h>

extern "C" __device__ uint32_t dlto_stage_bits(int t, int iters, int tail_mask, int stage_mask);
extern "C" __device__ uint64_t dlto_byte_bump(int t, uint64_t stride, uint32_t bits);
extern "C" __device__ float dlto_mix_values(float acc,
                                            const float *base,
                                            int lane,
                                            uint32_t bits,
                                            uint64_t byte_off);
extern "C" __global__ void probe_dlto_cross_tu(float *out,
                                               const float *a_in,
                                               const float *b_in,
                                               const float *base,
                                               int iters,
                                               uint64_t stride,
                                               int tail_mask,
                                               int stage_mask);
