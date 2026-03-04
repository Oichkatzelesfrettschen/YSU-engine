// gpu_bvh_lbvh_builder.h - LBVH-based GPU BVH builder
#pragma once

#include <stdint.h>
#include "gpu_bvh.h"

#ifdef __cplusplus
extern "C" {
#endif

// Build GPU BVH using Linear BVH with Morton codes
// Provides better spatial locality and cache performance than standard BVH
//
// tri_data: flat array of triangles (12 floats per triangle: p0.xyz, nx, p1.xyz, ny, p2.xyz, nz)
// tri_count: number of triangles
// out_nodes: output GPU BVH nodes (allocated by this function)
// out_node_count: number of nodes in output BVH
// out_indices: output triangle index remapping (Morton-sorted order)
// out_index_count: triangle count (same as tri_count)
//
// Returns: 1 on success, 0 on failure
int gpu_build_bvh_lbvh(
    const float* tri_data,
    uint32_t tri_count,
    GPUBVHNode** out_nodes,
    uint32_t* out_node_count,
    int32_t** out_indices,
    uint32_t* out_index_count
);

#ifdef __cplusplus
}
#endif
