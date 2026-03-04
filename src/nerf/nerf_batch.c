#include "nerf_batch.h"
#include <stdlib.h>
#include <string.h>

static void* zalloc_array(size_t count, size_t elem_size){
    void* p = malloc(count * elem_size);
    if(p) memset(p, 0, count * elem_size);
    return p;
}

int nerf_ray_batch_init(NerfRayBatch* b, uint32_t capacity){
    if(!b || capacity == 0) return 0;
    memset(b, 0, sizeof(*b));
    b->capacity = capacity;

    b->pix = (uint32_t*)zalloc_array(capacity, sizeof(uint32_t));
    b->ox = (float*)zalloc_array(capacity, sizeof(float));
    b->oy = (float*)zalloc_array(capacity, sizeof(float));
    b->oz = (float*)zalloc_array(capacity, sizeof(float));
    b->dx = (float*)zalloc_array(capacity, sizeof(float));
    b->dy = (float*)zalloc_array(capacity, sizeof(float));
    b->dz = (float*)zalloc_array(capacity, sizeof(float));
    b->tmin = (float*)zalloc_array(capacity, sizeof(float));
    b->tmax = (float*)zalloc_array(capacity, sizeof(float));

    if(!b->pix || !b->ox || !b->oy || !b->oz || !b->dx || !b->dy || !b->dz || !b->tmin || !b->tmax){
        nerf_ray_batch_free(b);
        return 0;
    }
    return 1;
}

void nerf_ray_batch_free(NerfRayBatch* b){
    if(!b) return;
    free(b->pix);
    free(b->ox); free(b->oy); free(b->oz);
    free(b->dx); free(b->dy); free(b->dz);
    free(b->tmin); free(b->tmax);
    memset(b, 0, sizeof(*b));
}

int nerf_sample_batch_init(NerfSampleBatch* b, uint32_t capacity){
    if(!b || capacity == 0) return 0;
    memset(b, 0, sizeof(*b));
    b->capacity = capacity;

    b->px = (float*)zalloc_array(capacity, sizeof(float));
    b->py = (float*)zalloc_array(capacity, sizeof(float));
    b->pz = (float*)zalloc_array(capacity, sizeof(float));
    b->vx = (float*)zalloc_array(capacity, sizeof(float));
    b->vy = (float*)zalloc_array(capacity, sizeof(float));
    b->vz = (float*)zalloc_array(capacity, sizeof(float));

    b->r = (float*)zalloc_array(capacity, sizeof(float));
    b->g = (float*)zalloc_array(capacity, sizeof(float));
    b->b = (float*)zalloc_array(capacity, sizeof(float));
    b->sigma = (float*)zalloc_array(capacity, sizeof(float));

    if(!b->px || !b->py || !b->pz || !b->vx || !b->vy || !b->vz || !b->r || !b->g || !b->b || !b->sigma){
        nerf_sample_batch_free(b);
        return 0;
    }
    return 1;
}

void nerf_sample_batch_free(NerfSampleBatch* b){
    if(!b) return;
    free(b->px); free(b->py); free(b->pz);
    free(b->vx); free(b->vy); free(b->vz);
    free(b->r); free(b->g); free(b->b); free(b->sigma);
    memset(b, 0, sizeof(*b));
}
