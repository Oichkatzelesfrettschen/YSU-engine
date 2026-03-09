// gpu_bvh_build.h
#pragma once
#include <stdint.h>
#include <stddef.h>
#include "gpu_bvh.h"

#ifdef __cplusplus
extern "C" {
#endif

// tri_data format: 3 vec4 per triangle (p0,p1,p2) => 12 floats each
// tri_data size: tri_count * 12 floats
//
// Outputs:
//   out_nodes: GPUBVHNode array (allocated with malloc, caller must free)
//   out_node_count: node count
//   out_indices: int32 triangle index list (permuted) (allocated with malloc, caller must free)
//   out_index_count: same as tri_count
//
// leaf node: left=right=-1, triOffset/triCount index list segmentine bakar.
int gpu_build_bvh_from_tri_vec4(
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
