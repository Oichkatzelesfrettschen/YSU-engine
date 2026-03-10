#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stddef.h>

/* Minimal Vulkan stubs for headless testing */
#define VK_DEFINE_HANDLE(object) typedef struct object##_T* object;
VK_DEFINE_HANDLE(VkInstance);
VK_DEFINE_HANDLE(VkPhysicalDevice);
VK_DEFINE_HANDLE(VkDevice);
VK_DEFINE_HANDLE(VkQueue);
VK_DEFINE_HANDLE(VkBuffer);
VK_DEFINE_HANDLE(VkDeviceMemory);
VK_DEFINE_HANDLE(VkPipeline);
VK_DEFINE_HANDLE(VkPipelineLayout);
VK_DEFINE_HANDLE(VkDescriptorSetLayout);
VK_DEFINE_HANDLE(VkDescriptorPool);
VK_DEFINE_HANDLE(VkDescriptorSet);
VK_DEFINE_HANDLE(VkShaderModule);
VK_DEFINE_HANDLE(VkCommandPool);
VK_DEFINE_HANDLE(VkCommandBuffer);

#define VK_SUCCESS 0
#define VK_NULL_HANDLE 0
#define VK_WHOLE_SIZE 0xFFFFFFFFFFFFFFFFULL
#define UINT32_MAX 0xFFFFFFFF

/* Vulkan function stubs that do nothing */
#define vkCreateBuffer(...)return 0;
#define vkGetBufferMemoryRequirements(...)
#define vkAllocateMemory(...) return 0;
#define vkBindBufferMemory(...)  
#define vkMapMemory(a,b,c,d,e,f) { *(void**)f = malloc(1000000); return 0; }
#define vkUnmapMemory(...)
#define vkDestroyBuffer(...)
#define vkFreeMemory(...)
#define vkCreateCommandPool(...) return 0;
#define vkAllocateCommandBuffers(...) return 0;
#define vkResetCommandBuffer(...) return 0;
#define vkBeginCommandBuffer(...) return 0;
#define vkEndCommandBuffer(...) return 0;
#define vkCreateShaderModule(...) return 0;
#define vkCreateDescriptorSetLayout(...) return 0;
#define vkCreateDescriptorPool(...) return 0;
#define vkAllocateDescriptorSets(...) return 0;
#define vkCreatePipelineLayout(...) return 0;
#define vkCreateComputePipelines(...) return 0;
#define vkUpdateDescriptorSets(...)
#define vkCmdBindPipeline(...)
#define vkCmdBindDescriptorSets(...)
#define vkCmdPipelineBarrier(...)
#define vkCmdCopyBuffer(...)
#define vkDestroyPipeline(...)
#define vkDestroyPipelineLayout(...)
#define vkDestroyDescriptorSetLayout(...)
#define vkDestroyDescriptorPool(...)
#define vkDestroyShaderModule(...)
#define vkDestroyCommandPool(...)

/* Test program */
int main() {
    printf("=== Reactor Thermal Struct Test ===\n");
    
    /* Simulate what quantum_demo_main.c does */
    typedef struct {
        int   gridDim;
        float boxHalf;
        float *temperature;
        float *heat_source;
        int   *material_id;
        float *pressure_field;
        float *void_fraction;
        
        int              n_channels;
        void *channels; /* placeholder */
        
        float total_power_w;
        float avg_fuel_temp;
        float max_fuel_temp;
        float avg_coolant_temp;
        float max_coolant_temp;
        float system_pressure;
        float total_steam_mass;
        float total_entropy;
        float energy_balance;
        
        float zr_oxidation_frac;
        float hydrogen_mass;
        
        float time;
        float dt;
        float power_fraction;
        int   scram_active;
        float scram_time;
        
        float void_coefficient;
        float reactivity;
        
        /* Vulkan stubs */
        void *device, *physDevice;
        void *diffusionPipeline, *diffusionPipeLayout;
        void *diffusionDescLayout, *diffusionDescPool, *diffusionDescSet;
        void *diffusionShader;
        void *tempBuf, *tempMem, *tempBuf2, *tempMem2;
        void *heatSrcBuf, *heatSrcMem;
        void *matBuf, *matMem;
        void *cmdPool, *cmdBuf;
        void *densityBuf, *signedBuf;
        int   visGridDim;
    } ReactorThermal_Test;
    
    printf("sizeof(ReactorThermal) = %zu bytes\n", sizeof(ReactorThermal_Test));
    printf("offset of power_fraction = %zu bytes\n", offsetof(ReactorThermal_Test, power_fraction));
    
    /* Test allocation and initialization like reactor_thermal_init does */
    ReactorThermal_Test rt;
    memset(&rt, 0, sizeof(rt));
    
    rt.gridDim = 64;
    rt.boxHalf = 7.0f;
    
    int total = 64 * 64 * 64;
    rt.temperature    = (float *)calloc(total, sizeof(float));
    rt.heat_source    = (float *)calloc(total, sizeof(float));
    rt.material_id    = (int *)calloc(total, sizeof(int));
    rt.pressure_field = (float *)calloc(total, sizeof(float));
    rt.void_fraction  = (float *)calloc(total, sizeof(float));
    
    printf("Grid allocations done\n");
    
    /* Set Vulkan fields */
    rt.system_pressure = 7.0e6f;
    rt.power_fraction = 0.07f;
    rt.total_power_w = rt.power_fraction * 3200.0e6f;
    rt.dt = 0.01f;
    rt.time = 0.0f;   
    rt.scram_active = 0;
    rt.hydrogen_mass = 0.0f;
    
    printf("Initial state set\n");
    printf("  power_fraction = %.6f (should be 0.070000)\n", rt.power_fraction);
    printf("  system_pressure = %.0f Pa (should be 7000000)\n", rt.system_pressure);
    printf("  total_power_w = %.0f W\n", rt.total_power_w);
    
    /* Simulate reactor_thermal_update */
    printf("\nSimulating temperature update...\n");
    for (int i = 0; i < total; i++) {
        rt.temperature[i] = 500.0f + (i % 100) * 5.0f;
    }
    
    /* Simulate update pressure */
    rt.system_pressure = 5.5e6f;  /* Changes like in the bug */
    
    printf("After update:\n");
    printf("  power_fraction = %.6f (should still be 0.070000!)\n", rt.power_fraction);
    printf("  system_pressure = %.0f Pa (should be 5500000)\n", rt.system_pressure);
    
    /* Check if power_fraction got corrupted */
    if (rt.power_fraction < 0.001f || rt.power_fraction > 0.1f) {
        printf("ERROR: power_fraction corrupted! Value=%.15f\n", rt.power_fraction);
        printf("In terms of %%: %.0f%%\n", rt.power_fraction * 100.0f);
        return 1;
    } else {
        printf("✓ power_fraction intact\n");
    }
    
    free(rt.temperature);
    free(rt.heat_source);
    free(rt.material_id);
    free(rt.pressure_field);
    free(rt.void_fraction);
    
    printf("\n=== Test PASSED ===\n");
    return 0;
}
