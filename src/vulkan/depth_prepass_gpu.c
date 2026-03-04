/**
 * @file depth_prepass_gpu.c
 * @brief GPU Integration for Depth-Conditioned NeRF Sampling - Implementation
 * 
 * Author: YSU Engine Research Team
 * Date: February 2026
 */

#include "depth_prepass_gpu.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
static uint64_t get_time_us(void) {
    static LARGE_INTEGER freq;
    static int inited = 0;
    if (!inited) { QueryPerformanceFrequency(&freq); inited = 1; }
    LARGE_INTEGER c; QueryPerformanceCounter(&c);
    return (uint64_t)((c.QuadPart * 1000000ULL) / (uint64_t)freq.QuadPart);
}
#else
#include <sys/time.h>
static uint64_t get_time_us(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000000ULL + (uint64_t)tv.tv_usec;
}
#endif

// ============================================================================
// Vulkan Helpers
// ============================================================================

static uint32_t find_memory_type(
    VkPhysicalDevice phy,
    uint32_t type_filter,
    VkMemoryPropertyFlags props
) {
    VkPhysicalDeviceMemoryProperties mem_props;
    vkGetPhysicalDeviceMemoryProperties(phy, &mem_props);
    
    for (uint32_t i = 0; i < mem_props.memoryTypeCount; i++) {
        if ((type_filter & (1u << i)) &&
            (mem_props.memoryTypes[i].propertyFlags & props) == props) {
            return i;
        }
    }
    return 0xFFFFFFFF;
}

static VkBuffer create_buffer_local(VkDevice dev, VkDeviceSize size, VkBufferUsageFlags usage) {
    VkBufferCreateInfo ci = { VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO };
    ci.size = size;
    ci.usage = usage;
    ci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    
    VkBuffer buf = VK_NULL_HANDLE;
    vkCreateBuffer(dev, &ci, NULL, &buf);
    return buf;
}

static VkDeviceMemory alloc_bind_buffer_local(
    VkPhysicalDevice phy,
    VkDevice dev,
    VkBuffer buf,
    VkMemoryPropertyFlags props
) {
    VkMemoryRequirements reqs;
    vkGetBufferMemoryRequirements(dev, buf, &reqs);
    
    VkMemoryAllocateInfo ai = { VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO };
    ai.allocationSize = reqs.size;
    ai.memoryTypeIndex = find_memory_type(phy, reqs.memoryTypeBits, props);
    
    VkDeviceMemory mem = VK_NULL_HANDLE;
    vkAllocateMemory(dev, &ai, NULL, &mem);
    vkBindBufferMemory(dev, buf, mem, 0);
    
    return mem;
}

// ============================================================================
// API Implementation
// ============================================================================

int depth_prepass_gpu_init(
    DepthPrepassGPU* gpu,
    VkPhysicalDevice phy,
    VkDevice dev,
    uint32_t width,
    uint32_t height
) {
    if (!gpu || width == 0 || height == 0) return 0;
    
    memset(gpu, 0, sizeof(*gpu));
    gpu->width = width;
    gpu->height = height;
    
    // Initialize CPU-side depth hint buffer
    if (!depth_hint_buffer_init(&gpu->cpu_hints, width, height)) {
        fprintf(stderr, "[DEPTH] Failed to init CPU hint buffer\n");
        return 0;
    }
    
    // Create GPU buffer (16 bytes per hint: vec4)
    // Each hint: depth(f32), delta(f32), confidence(f32), flags(f32 as bits)
    gpu->size = (VkDeviceSize)(width * height * 4 * sizeof(float));
    
    gpu->buffer = create_buffer_local(dev, gpu->size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT);
    if (gpu->buffer == VK_NULL_HANDLE) {
        fprintf(stderr, "[DEPTH] Failed to create GPU buffer\n");
        depth_hint_buffer_free(&gpu->cpu_hints);
        return 0;
    }
    
    gpu->memory = alloc_bind_buffer_local(
        phy, dev, gpu->buffer,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
    );
    
    if (gpu->memory == VK_NULL_HANDLE) {
        fprintf(stderr, "[DEPTH] Failed to allocate GPU memory\n");
        vkDestroyBuffer(dev, gpu->buffer, NULL);
        depth_hint_buffer_free(&gpu->cpu_hints);
        return 0;
    }
    
    // Map persistently
    VkResult r = vkMapMemory(dev, gpu->memory, 0, gpu->size, 0, &gpu->mapped);
    if (r != VK_SUCCESS) {
        fprintf(stderr, "[DEPTH] Failed to map GPU memory\n");
        vkFreeMemory(dev, gpu->memory, NULL);
        vkDestroyBuffer(dev, gpu->buffer, NULL);
        depth_hint_buffer_free(&gpu->cpu_hints);
        return 0;
    }
    
    // Initialize with fallback values
    memset(gpu->mapped, 0, (size_t)gpu->size);
    
    gpu->enabled = 1;
    
    fprintf(stderr, "[DEPTH] GPU prepass initialized: %ux%u (%.2f MB)\n",
            width, height, (float)gpu->size / (1024.0f * 1024.0f));
    
    return 1;
}

int depth_prepass_gpu_resize(
    DepthPrepassGPU* gpu,
    VkPhysicalDevice phy,
    VkDevice dev,
    uint32_t new_width,
    uint32_t new_height
) {
    if (!gpu || new_width == 0 || new_height == 0) return 0;
    if (gpu->width == new_width && gpu->height == new_height) return 1;
    
    // Free old resources
    if (gpu->memory != VK_NULL_HANDLE) {
        vkUnmapMemory(dev, gpu->memory);
        vkFreeMemory(dev, gpu->memory, NULL);
    }
    if (gpu->buffer != VK_NULL_HANDLE) {
        vkDestroyBuffer(dev, gpu->buffer, NULL);
    }
    depth_hint_buffer_free(&gpu->cpu_hints);
    
    // Reinitialize with new size
    gpu->width = new_width;
    gpu->height = new_height;
    
    if (!depth_hint_buffer_init(&gpu->cpu_hints, new_width, new_height)) {
        return 0;
    }
    
    gpu->size = (VkDeviceSize)(new_width * new_height * 4 * sizeof(float));
    gpu->buffer = create_buffer_local(dev, gpu->size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT);
    gpu->memory = alloc_bind_buffer_local(
        phy, dev, gpu->buffer,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
    );
    
    vkMapMemory(dev, gpu->memory, 0, gpu->size, 0, &gpu->mapped);
    
    fprintf(stderr, "[DEPTH] Resized to %ux%u\n", new_width, new_height);
    return 1;
}

int depth_prepass_gpu_build_proxy(
    DepthPrepassGPU* gpu,
    const uint8_t* occ_data,
    uint32_t occ_dim,
    float threshold,
    const float center[3],
    float scale
) {
    if (!gpu || !occ_data || occ_dim == 0) return 0;
    
    // Free old proxy if exists
    proxy_mesh_free(&gpu->proxy_mesh);
    depth_bvh_free(&gpu->cpu_bvh);
    
    // Extract proxy mesh from occupancy
    if (!proxy_mesh_from_occupancy(occ_data, occ_dim, threshold, center, scale, &gpu->proxy_mesh)) {
        fprintf(stderr, "[DEPTH] Failed to extract proxy mesh\n");
        return 0;
    }
    
    // Build BVH for proxy mesh
    if (!depth_bvh_build(&gpu->cpu_bvh, &gpu->proxy_mesh)) {
        fprintf(stderr, "[DEPTH] Failed to build proxy BVH\n");
        proxy_mesh_free(&gpu->proxy_mesh);
        return 0;
    }
    
    fprintf(stderr, "[DEPTH] Proxy BVH built: %u nodes\n", gpu->cpu_bvh.node_count);
    return 1;
}

void depth_prepass_gpu_compute_and_upload(
    DepthPrepassGPU* gpu,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    float delta,
    int num_threads
) {
    if (!gpu || !gpu->enabled || !gpu->mapped) return;
    
    uint64_t t0 = get_time_us();
    
    // Check if we have a valid BVH
    if (gpu->cpu_bvh.nodes && gpu->cpu_bvh.node_count > 0) {
        // Compute depth hints using CPU BVH
        if (num_threads <= 0) num_threads = 4;  // Default to 4 threads
        
        depth_prepass_compute_mt(
            &gpu->cpu_bvh,
            cam_pos,
            cam_forward,
            cam_right,
            cam_up,
            fov_y,
            gpu->width,
            gpu->height,
            &gpu->cpu_hints,
            delta,
            num_threads
        );
    } else {
        // No BVH: fill with fallback values
        depth_hint_buffer_clear(&gpu->cpu_hints);
    }
    
    uint64_t t1 = get_time_us();
    gpu->last_prepass_ms = (float)(t1 - t0) / 1000.0f;
    gpu->last_hit_rate = depth_hint_buffer_hit_rate(&gpu->cpu_hints);
    
    // Upload to GPU
    // Convert DepthHint structs to vec4 array
    float* dst = (float*)gpu->mapped;
    for (uint32_t i = 0; i < gpu->cpu_hints.count; i++) {
        const DepthHint* hint = &gpu->cpu_hints.hints[i];
        dst[i * 4 + 0] = hint->depth;
        dst[i * 4 + 1] = hint->delta;
        dst[i * 4 + 2] = hint->confidence;
        // Pack flags as float bits
        uint32_t flags = hint->flags;
        float flags_f;
        memcpy(&flags_f, &flags, sizeof(float));
        dst[i * 4 + 3] = flags_f;
    }
}

VkDescriptorBufferInfo depth_prepass_gpu_descriptor_info(const DepthPrepassGPU* gpu) {
    VkDescriptorBufferInfo info = {0};
    if (gpu && gpu->buffer != VK_NULL_HANDLE) {
        info.buffer = gpu->buffer;
        info.offset = 0;
        info.range = gpu->size;
    }
    return info;
}

void depth_prepass_gpu_free(DepthPrepassGPU* gpu, VkDevice dev) {
    if (!gpu) return;
    
    // Free Vulkan resources
    if (gpu->memory != VK_NULL_HANDLE) {
        if (gpu->mapped) {
            vkUnmapMemory(dev, gpu->memory);
            gpu->mapped = NULL;
        }
        vkFreeMemory(dev, gpu->memory, NULL);
        gpu->memory = VK_NULL_HANDLE;
    }
    if (gpu->buffer != VK_NULL_HANDLE) {
        vkDestroyBuffer(dev, gpu->buffer, NULL);
        gpu->buffer = VK_NULL_HANDLE;
    }
    
    // Free CPU resources
    depth_hint_buffer_free(&gpu->cpu_hints);
    depth_bvh_free(&gpu->cpu_bvh);
    proxy_mesh_free(&gpu->proxy_mesh);
    
    memset(gpu, 0, sizeof(*gpu));
}

void depth_prepass_gpu_print_stats(const DepthPrepassGPU* gpu) {
    if (!gpu) return;
    
    printf("[DEPTH] Prepass Stats:\n");
    printf("  Enabled: %s\n", gpu->enabled ? "yes" : "no");
    printf("  Resolution: %u x %u\n", gpu->width, gpu->height);
    printf("  Buffer size: %.2f MB\n", (float)gpu->size / (1024.0f * 1024.0f));
    printf("  Last prepass: %.2f ms\n", gpu->last_prepass_ms);
    printf("  Hit rate: %.1f%%\n", gpu->last_hit_rate * 100.0f);
    printf("  Proxy mesh: %u triangles\n", gpu->proxy_mesh.triangle_count);
    printf("  BVH nodes: %u\n", gpu->cpu_bvh.node_count);
}
