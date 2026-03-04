/**
 * @file depth_prepass_gpu.h
 * @brief GPU Integration for Depth-Conditioned NeRF Sampling
 * 
 * Provides Vulkan buffer management for passing CPU depth hints to GPU shader.
 * 
 * Usage:
 *   1. Initialize with depth_prepass_gpu_init()
 *   2. Each frame: compute depth hints, then call depth_prepass_gpu_upload()
 *   3. Bind the buffer at binding 10 in your descriptor set
 *   4. Use renderMode=26 for depth-conditioned NeRF rendering
 * 
 * Author: YSU Engine Research Team
 * Date: February 2026
 */

#ifndef DEPTH_PREPASS_GPU_H
#define DEPTH_PREPASS_GPU_H

#include <vulkan/vulkan.h>
#include "depth_hint.h"

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// GPU Resources
// ============================================================================

/**
 * @brief Vulkan resources for depth hint buffer
 */
typedef struct DepthPrepassGPU {
    VkBuffer buffer;
    VkDeviceMemory memory;
    VkDeviceSize size;
    void* mapped;  // Persistently mapped for CPU writes
    
    // Current frame dimensions
    uint32_t width;
    uint32_t height;
    
    // CPU-side depth prepass resources
    DepthHintBuffer cpu_hints;
    DepthBVH cpu_bvh;
    ProxyMesh proxy_mesh;
    
    // Stats
    int enabled;
    float last_prepass_ms;
    float last_hit_rate;
} DepthPrepassGPU;

// ============================================================================
// API Functions
// ============================================================================

/**
 * @brief Initialize GPU resources for depth prepass
 * 
 * @param gpu           Output GPU resources
 * @param phy           Vulkan physical device
 * @param dev           Vulkan device
 * @param width         Frame width
 * @param height        Frame height
 * @return 1 on success, 0 on failure
 */
int depth_prepass_gpu_init(
    DepthPrepassGPU* gpu,
    VkPhysicalDevice phy,
    VkDevice dev,
    uint32_t width,
    uint32_t height
);

/**
 * @brief Resize depth prepass buffers
 */
int depth_prepass_gpu_resize(
    DepthPrepassGPU* gpu,
    VkPhysicalDevice phy,
    VkDevice dev,
    uint32_t new_width,
    uint32_t new_height
);

/**
 * @brief Build proxy mesh from occupancy grid
 * 
 * Call this after loading NeRF model to extract proxy geometry.
 */
int depth_prepass_gpu_build_proxy(
    DepthPrepassGPU* gpu,
    const uint8_t* occ_data,
    uint32_t occ_dim,
    float threshold,
    const float center[3],
    float scale
);

/**
 * @brief Compute depth prepass and upload to GPU
 * 
 * @param gpu           GPU resources
 * @param cam_pos       Camera position [3]
 * @param cam_forward   Camera forward direction [3]
 * @param cam_right     Camera right direction [3]
 * @param cam_up        Camera up direction [3]
 * @param fov_y         Vertical field of view (radians)
 * @param delta         Sampling half-width (default: 0.3)
 * @param num_threads   Number of CPU threads for prepass (0 = auto)
 */
void depth_prepass_gpu_compute_and_upload(
    DepthPrepassGPU* gpu,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    float delta,
    int num_threads
);

/**
 * @brief Get descriptor buffer info for binding
 */
VkDescriptorBufferInfo depth_prepass_gpu_descriptor_info(const DepthPrepassGPU* gpu);

/**
 * @brief Free GPU resources
 */
void depth_prepass_gpu_free(DepthPrepassGPU* gpu, VkDevice dev);

/**
 * @brief Print prepass statistics
 */
void depth_prepass_gpu_print_stats(const DepthPrepassGPU* gpu);

#ifdef __cplusplus
}
#endif

#endif // DEPTH_PREPASS_GPU_H
