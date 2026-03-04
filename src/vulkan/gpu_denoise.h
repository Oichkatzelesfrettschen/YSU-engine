// gpu_denoise.h - GPU denoiser pipeline integration
// Separable bilateral filter running on Vulkan compute

#ifndef GPU_DENOISE_H
#define GPU_DENOISE_H

#include <vulkan/vulkan.h>

typedef struct {
    VkShaderModule shader_module;
    VkPipelineLayout layout;
    VkDescriptorSetLayout dsl;
    VkDescriptorPool pool;
    VkDescriptorSet descriptor_set;
    VkPipeline pipeline;
    
    int enabled;
    int radius;
    float sigma_s;  // spatial std dev
    float sigma_r;  // range std dev
} GPUDenoiser;

// Returns 0 on success, 1 on failure
int gpu_denoise_init(
    GPUDenoiser *denoise,
    VkDevice dev,
    VkImage in_image,
    VkImage out_image,
    VkImageView in_view,
    VkImageView out_view);

void gpu_denoise_dispatch(
    GPUDenoiser *denoise,
    VkCommandBuffer cb,
    int W, int H,
    int pass);  // 0=horizontal, 1=vertical

void gpu_denoise_cleanup(
    GPUDenoiser *denoise,
    VkDevice dev);

#endif // GPU_DENOISE_H
