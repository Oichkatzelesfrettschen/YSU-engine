/**
 * @file depth_hint.h
 * @brief CPU-GPU Heterogeneous Depth-Conditioned NeRF Sampling
 * 
 * Research: Depth-aware sparse sampling for real-time neural radiance fields.
 * 
 * Core Concept:
 *   CPU performs fast BVH traversal against proxy geometry to get depth hints.
 *   GPU uses depth hints to narrow NeRF sampling from [t_near, t_far] to [depth-δ, depth+δ].
 *   This reduces MLP evaluations by 4-8x while maintaining quality.
 * 
 * Paper: "Depth-Conditioned Heterogeneous NeRF: CPU-Guided Sparse Sampling 
 *         for Real-Time Neural Rendering"
 * 
 * Author: YSU Engine Research Team
 * Date: February 2026
 */

#ifndef DEPTH_HINT_H
#define DEPTH_HINT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Configuration
// ============================================================================

// Default narrow-band delta (half-width around depth hint)
#define DEPTH_HINT_DEFAULT_DELTA 0.3f

// Maximum delta (for low-confidence hits)
#define DEPTH_HINT_MAX_DELTA 2.0f

// Fallback t_near/t_far for misses
#define DEPTH_HINT_FALLBACK_NEAR 2.0f
#define DEPTH_HINT_FALLBACK_FAR  6.0f

// ============================================================================
// Per-Ray Depth Hint Structure
// ============================================================================

/**
 * @brief Per-ray depth hint from CPU BVH prepass
 * 
 * Packed for efficient GPU transfer (16 bytes per ray)
 */
typedef struct DepthHint {
    float depth;      // Estimated depth from CPU BVH trace
    float delta;      // Sampling half-width: sample [depth-delta, depth+delta]
    float confidence; // 0.0 = miss (use fallback), 1.0 = confident hit
    uint32_t flags;   // Bit 0: valid, Bit 1: used fallback, Bits 2-7: reserved
} DepthHint;

// Flag bits
#define DEPTH_HINT_FLAG_VALID    (1u << 0)
#define DEPTH_HINT_FLAG_FALLBACK (1u << 1)
#define DEPTH_HINT_FLAG_SURFACE  (1u << 2)  // Hit actual surface (not bounding volume)

// ============================================================================
// Depth Hint Buffer (for full frame)
// ============================================================================

/**
 * @brief Frame-sized buffer of depth hints
 */
typedef struct DepthHintBuffer {
    uint32_t width;
    uint32_t height;
    uint32_t count;      // width * height
    DepthHint* hints;    // CPU-side storage
    
    // Statistics for adaptive delta
    uint64_t hits;
    uint64_t misses;
    float avg_depth;
    float depth_variance;
} DepthHintBuffer;

// ============================================================================
// Proxy Mesh for CPU BVH
// ============================================================================

/**
 * @brief Simplified proxy mesh extracted from NeRF density
 * 
 * This is a coarse approximation of NeRF geometry for fast CPU ray tracing.
 * Can be generated via marching cubes on the occupancy grid.
 */
typedef struct ProxyMesh {
    float* vertices;     // x,y,z per vertex
    uint32_t* indices;   // Triangle indices
    uint32_t vertex_count;
    uint32_t triangle_count;
    
    // Bounding box
    float bbox_min[3];
    float bbox_max[3];
} ProxyMesh;

// ============================================================================
// CPU BVH for Proxy Mesh
// ============================================================================

/**
 * @brief Simple BVH node for CPU depth prepass
 */
typedef struct DepthBVHNode {
    float bbox_min[3];
    float bbox_max[3];
    int32_t left;        // -1 for leaf
    int32_t right;       // -1 for leaf
    int32_t tri_start;   // First triangle index
    int32_t tri_count;   // Number of triangles (>0 for leaf)
} DepthBVHNode;

/**
 * @brief CPU BVH structure for proxy mesh
 */
typedef struct DepthBVH {
    DepthBVHNode* nodes;
    uint32_t node_count;
    int32_t* tri_indices;
    uint32_t index_count;
    const ProxyMesh* mesh;  // Reference to proxy mesh
} DepthBVH;

// ============================================================================
// API Functions
// ============================================================================

// --- Buffer Management ---

/**
 * @brief Initialize depth hint buffer for given resolution
 */
int depth_hint_buffer_init(DepthHintBuffer* buf, uint32_t width, uint32_t height);

/**
 * @brief Free depth hint buffer
 */
void depth_hint_buffer_free(DepthHintBuffer* buf);

/**
 * @brief Clear buffer to invalid/fallback state
 */
void depth_hint_buffer_clear(DepthHintBuffer* buf);

// --- Proxy Mesh Generation ---

/**
 * @brief Extract proxy mesh from NeRF occupancy grid using marching cubes
 * 
 * @param occ_data      Occupancy grid data (64^3 bytes)
 * @param occ_dim       Occupancy grid dimension (e.g., 64)
 * @param threshold     Density threshold for surface extraction
 * @param center        NeRF scene center [3]
 * @param scale         NeRF scene scale
 * @param out_mesh      Output proxy mesh
 * @return 1 on success, 0 on failure
 */
int proxy_mesh_from_occupancy(
    const uint8_t* occ_data,
    uint32_t occ_dim,
    float threshold,
    const float center[3],
    float scale,
    ProxyMesh* out_mesh
);

/**
 * @brief Free proxy mesh
 */
void proxy_mesh_free(ProxyMesh* mesh);

// --- BVH Building ---

/**
 * @brief Build BVH for proxy mesh
 */
int depth_bvh_build(DepthBVH* bvh, const ProxyMesh* mesh);

/**
 * @brief Free BVH
 */
void depth_bvh_free(DepthBVH* bvh);

// --- Depth Prepass ---

/**
 * @brief Compute depth hints for entire frame (single-threaded)
 * 
 * @param bvh           CPU BVH of proxy mesh
 * @param cam_pos       Camera position [3]
 * @param cam_forward   Camera forward direction [3]
 * @param cam_right     Camera right direction [3]
 * @param cam_up        Camera up direction [3]
 * @param fov_y         Vertical field of view (radians)
 * @param width         Image width
 * @param height        Image height
 * @param out_hints     Output depth hint buffer
 * @param default_delta Default sampling delta
 */
void depth_prepass_compute(
    const DepthBVH* bvh,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    uint32_t width,
    uint32_t height,
    DepthHintBuffer* out_hints,
    float default_delta
);

/**
 * @brief Compute depth hints (multi-threaded)
 */
void depth_prepass_compute_mt(
    const DepthBVH* bvh,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    uint32_t width,
    uint32_t height,
    DepthHintBuffer* out_hints,
    float default_delta,
    int num_threads
);

// --- Single Ray Trace ---

/**
 * @brief Trace single ray against BVH, return depth
 * 
 * @return Depth (t value), or -1.0f on miss
 */
float depth_bvh_trace_ray(
    const DepthBVH* bvh,
    const float origin[3],
    const float direction[3],
    float t_min,
    float t_max
);

// --- Statistics ---

/**
 * @brief Get hit rate from last prepass
 */
float depth_hint_buffer_hit_rate(const DepthHintBuffer* buf);

/**
 * @brief Print depth prepass statistics
 */
void depth_hint_buffer_print_stats(const DepthHintBuffer* buf);

#ifdef __cplusplus
}
#endif

#endif // DEPTH_HINT_H
