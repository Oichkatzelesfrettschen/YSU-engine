#ifndef NERF_SCHEDULER_H
#define NERF_SCHEDULER_H

#include <stdint.h>
#include "nerf_batch.h"

// Simple scheduler config for CPU/GPU split
typedef struct NerfScheduleConfig {
    uint32_t batch_size;   // e.g., 4096
    float cpu_share;       // 0..1, fraction of rays routed to CPU
    float fovea_radius;    // normalized [0..1], center radius routed to GPU
} NerfScheduleConfig;

// Output queues (CPU/GPU batches)
typedef struct NerfScheduleQueues {
    NerfRayBatch gpu;
    NerfRayBatch cpu;
} NerfScheduleQueues;

int nerf_scheduler_init(NerfScheduleQueues* q, uint32_t batch_size);
void nerf_scheduler_free(NerfScheduleQueues* q);

// Basic split: center -> GPU, periphery -> CPU (placeholder)
// Inputs are arrays for a full frame; outputs are filled batches.
void nerf_schedule_split(const NerfScheduleConfig* cfg,
                         const NerfRayBatch* frame_rays,
                         NerfScheduleQueues* out);

#endif
