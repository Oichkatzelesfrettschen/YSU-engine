#ifndef HOST_WRAPPERS_H
#define HOST_WRAPPERS_H

#include <cuda_runtime.h>
#include "lbm_kernels.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int nx, ny, nz;
    int n_cells;
} LBMGrid;

typedef struct {
    void* f_a;
    void* f_b;
    void* f_c;
    void* f_d;
    float* rho;
    float* u;
    float* tau;
    float* force;
} LBMBuffers;

static inline LBMGrid lbm_grid_make(int nx, int ny, int nz) {
    LBMGrid g;
    g.nx = nx;
    g.ny = ny;
    g.nz = nz;
    g.n_cells = nx * ny * nz;
    return g;
}

int launch_lbm_step(
    LbmKernelVariant variant,
    const LBMGrid* grid,
    LBMBuffers* bufs,
    const void* f_in,
    void* f_out,
    int parity,
    cudaStream_t stream
);

int launch_lbm_init(
    LbmKernelVariant variant,
    const LBMGrid* grid,
    LBMBuffers* bufs,
    float rho_init,
    float ux_init, float uy_init, float uz_init,
    cudaStream_t stream
);

typedef struct {
    LbmKernelVariant variant;
    int max_active_blocks;
    int max_warps;
    float occupancy_pct;
} OccupancyInfo;

int query_occupancy(LbmKernelVariant variant, int device_id, OccupancyInfo* out);
void report_all_occupancy(int device_id);

#ifdef __cplusplus
}
#endif

#endif // HOST_WRAPPERS_H
