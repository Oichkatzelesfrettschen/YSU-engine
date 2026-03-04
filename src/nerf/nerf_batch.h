#ifndef NERF_BATCH_H
#define NERF_BATCH_H

#include <stdint.h>
#include <stddef.h>

// AVX2-friendly ray batch (Structure of Arrays)
// Batch size should be a multiple of 8 for AVX2 lanes.

typedef struct NerfRayBatch {
    uint32_t count;
    uint32_t capacity;

    // Pixel ids (linear index) for compositing
    uint32_t* pix;

    // Ray origins
    float* ox;
    float* oy;
    float* oz;

    // Ray directions
    float* dx;
    float* dy;
    float* dz;

    // Ray interval
    float* tmin;
    float* tmax;
} NerfRayBatch;

// Sample request batch (for GPU evaluation)
typedef struct NerfSampleBatch {
    uint32_t count;
    uint32_t capacity;

    // Sample position
    float* px;
    float* py;
    float* pz;

    // View direction (optional for color head)
    float* vx;
    float* vy;
    float* vz;

    // Output (rgb + sigma)
    float* r;
    float* g;
    float* b;
    float* sigma;
} NerfSampleBatch;

// Allocation helpers (SoA arrays)
int nerf_ray_batch_init(NerfRayBatch* b, uint32_t capacity);
void nerf_ray_batch_free(NerfRayBatch* b);

int nerf_sample_batch_init(NerfSampleBatch* b, uint32_t capacity);
void nerf_sample_batch_free(NerfSampleBatch* b);

#endif
