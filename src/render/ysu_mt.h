// ysu_mt.h
#ifndef YSU_MT_H
#define YSU_MT_H

#include <stdint.h>

// Basit xorshift RNG (thread-safe)
typedef struct {
    uint32_t state;
} YSU_Rng;

static inline uint32_t ysu_rng_u32(YSU_Rng *r) {
    // xorshift32
    uint32_t x = r->state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    r->state = x;
    return x;
}

static inline float ysu_rng_f01(YSU_Rng *r) {
    // [0,1)
    // 24-bit mantissa
    return (ysu_rng_u32(r) >> 8) * (1.0f / 16777216.0f);
}

// Suggested thread count (can be overridden via env)
int ysu_mt_suggest_threads(void);

// Worker context for the render tile job system
typedef struct {
    int width;
    int height;
    int spp;
    int max_depth;
    int tile_size;
    void *user; // context pointer for the render side
} YSU_RenderJobConfig;

#endif
