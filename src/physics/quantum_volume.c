/* quantum_volume.c — Vulkan host code for quantum wavefunction visualization.
 *
 * Two-pass compute pipeline:
 *   Pass 1 (quantum_wavefunction.comp): evaluate Σ|ψ_i|² on 3D SSBO grid
 *   Pass 2 (quantum_raymarch.comp): volume raymarch → 2D output image
 *
 * Follows YSU engine conventions:
 *   - Manual vkAllocateMemory (no VMA)
 *   - SSBO for volumetric data (no 3D textures)
 *   - Push constants for per-dispatch params
 *   - Single queue for compute
 */

#include "quantum_volume.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ═══════════════════════ VULKAN HELPERS ═══════════════════════
 * Mirrors gpu_vulkan_demo.c utilities. */

static uint32_t qv_find_mem_type(VkPhysicalDevice phys, uint32_t type_bits,
                                 VkMemoryPropertyFlags props) {
    VkPhysicalDeviceMemoryProperties mem;
    vkGetPhysicalDeviceMemoryProperties(phys, &mem);
    for (uint32_t i = 0; i < mem.memoryTypeCount; i++) {
        if ((type_bits & (1u << i)) &&
            (mem.memoryTypes[i].propertyFlags & props) == props)
            return i;
    }
    return UINT32_MAX;
}

static int qv_create_buffer(VkPhysicalDevice phys, VkDevice dev,
                            VkDeviceSize size, VkBufferUsageFlags usage,
                            VkMemoryPropertyFlags props,
                            VkBuffer *buf, VkDeviceMemory *mem) {
    VkBufferCreateInfo ci = {VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
    ci.size  = size;
    ci.usage = usage;
    if (vkCreateBuffer(dev, &ci, NULL, buf) != VK_SUCCESS) return -1;

    VkMemoryRequirements req;
    vkGetBufferMemoryRequirements(dev, *buf, &req);

    VkMemoryAllocateInfo ai = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    ai.allocationSize  = req.size;
    ai.memoryTypeIndex = qv_find_mem_type(phys, req.memoryTypeBits, props);
    if (ai.memoryTypeIndex == UINT32_MAX) return -2;
    if (vkAllocateMemory(dev, &ai, NULL, mem) != VK_SUCCESS) return -3;
    vkBindBufferMemory(dev, *buf, *mem, 0);
    return 0;
}

static int qv_create_image_2d(VkPhysicalDevice phys, VkDevice dev,
                              int W, int H, VkFormat fmt,
                              VkImageUsageFlags usage,
                              VkImage *img, VkImageView *view,
                              VkDeviceMemory *mem) {
    VkImageCreateInfo ci = {VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    ci.imageType   = VK_IMAGE_TYPE_2D;
    ci.format      = fmt;
    ci.extent      = (VkExtent3D){(uint32_t)W, (uint32_t)H, 1};
    ci.mipLevels   = 1;
    ci.arrayLayers = 1;
    ci.samples     = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling      = VK_IMAGE_TILING_OPTIMAL;
    ci.usage       = usage;
    if (vkCreateImage(dev, &ci, NULL, img) != VK_SUCCESS) return -1;

    VkMemoryRequirements req;
    vkGetImageMemoryRequirements(dev, *img, &req);

    VkMemoryAllocateInfo ai = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    ai.allocationSize  = req.size;
    ai.memoryTypeIndex = qv_find_mem_type(phys, req.memoryTypeBits,
                                          VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    if (ai.memoryTypeIndex == UINT32_MAX) return -2;
    if (vkAllocateMemory(dev, &ai, NULL, mem) != VK_SUCCESS) return -3;
    vkBindImageMemory(dev, *img, *mem, 0);

    VkImageViewCreateInfo vi = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
    vi.image    = *img;
    vi.viewType = VK_IMAGE_VIEW_TYPE_2D;
    vi.format   = fmt;
    vi.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    vi.subresourceRange.levelCount = 1;
    vi.subresourceRange.layerCount = 1;
    if (vkCreateImageView(dev, &vi, NULL, view) != VK_SUCCESS) return -4;
    return 0;
}

static VkShaderModule qv_load_shader(VkDevice dev, const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "[QV] Cannot open shader: %s\n", path); return VK_NULL_HANDLE; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint32_t *code = (uint32_t *)malloc((size_t)sz);
    if (!code) { fclose(f); return VK_NULL_HANDLE; }
    fread(code, 1, (size_t)sz, f);
    fclose(f);

    VkShaderModuleCreateInfo ci = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
    ci.codeSize = (size_t)sz;
    ci.pCode    = code;
    VkShaderModule mod = VK_NULL_HANDLE;
    vkCreateShaderModule(dev, &ci, NULL, &mod);
    free(code);
    return mod;
}

static void qv_submit_and_wait(VkDevice dev, VkQueue queue, VkCommandBuffer cmd) {
    VkSubmitInfo si = {VK_STRUCTURE_TYPE_SUBMIT_INFO};
    si.commandBufferCount = 1;
    si.pCommandBuffers    = &cmd;
    vkQueueSubmit(queue, 1, &si, VK_NULL_HANDLE);
    vkQueueWaitIdle(queue);
}

/* ═══════════════════════ SLATER'S RULES ═══════════════════════
 * Computes Z_eff = Z - S  where S is the Slater screening constant.
 *
 * Grouping: (1s)(2s,2p)(3s,3p)(3d)(4s,4p)(4d)(4f)(5s,5p)...
 *
 * Rules for an electron in group with principal quantum number n*:
 *   - Same group:         0.35 each (0.30 for 1s pair)
 *   - One group inside:   0.85 each (for s,p) or 1.00 (for d,f)
 *   - Two+ groups inside: 1.00 each
 *
 * For d/f electrons, ALL inner electrons screen by 1.00.
 */
float quantum_slater_z_eff(int Z, int n, int l) {
    /* Simplified Slater computation.
     * Electron configuration via Aufbau for Z up to 30. */

    /* Orbital filling order: 1s, 2s, 2p, 3s, 3p, 4s, 3d, 4p, 5s, 4d, 5p, ... */
    /* Max electrons per subshell: s=2, p=6, d=10, f=14 */
    static const struct { int n, l, max_e; } aufbau[] = {
        {1,0,2}, {2,0,2}, {2,1,6}, {3,0,2}, {3,1,6},
        {4,0,2}, {3,2,10},{4,1,6}, {5,0,2}, {4,2,10},
        {5,1,6}, {6,0,2}, {4,3,14},{5,2,10},{6,1,6},
        {7,0,2}, {5,3,14},{6,2,10},{7,1,6}
    };
    int n_subshells = (int)(sizeof(aufbau)/sizeof(aufbau[0]));

    /* Fill electrons */
    int electrons[19] = {0};
    int remaining = Z;
    for (int i = 0; i < n_subshells && remaining > 0; i++) {
        electrons[i] = remaining < aufbau[i].max_e ? remaining : aufbau[i].max_e;
        remaining -= electrons[i];
    }

    /* Find the target subshell index */
    int target_idx = -1;
    for (int i = 0; i < n_subshells; i++) {
        if (aufbau[i].n == n && aufbau[i].l == l) {
            target_idx = i;
            break;
        }
    }
    if (target_idx < 0) return (float)Z; /* Unknown orbital, no screening */

    /* Slater group number: map (n,l) → group
     * (1s)=0, (2s,2p)=1, (3s,3p)=2, (3d)=3, (4s,4p)=4, (4d)=5, (4f)=6, (5s,5p)=7 */
    /* Slater group classification (used implicitly via inner-shell logic below) */
    (void)0; /* d/f vs s/p distinction handled by 'l >= 2' checks */

    float S = 0.0f;
    int same_count = electrons[target_idx] - 1; /* exclude self */
    if (same_count < 0) same_count = 0;

    /* Same-group screening */
    if (n == 1)
        S += 0.30f * (float)same_count; /* 1s special case */
    else
        S += 0.35f * (float)same_count;

    /* Also count same-group partners (e.g., 2s contributes to 2p and vice versa) */
    for (int i = 0; i < n_subshells; i++) {
        if (i == target_idx) continue;
        if (aufbau[i].n == n && aufbau[i].l <= 1 && l <= 1 && aufbau[i].n == aufbau[target_idx].n) {
            /* Same (n,s/p) group */
            S += 0.35f * (float)electrons[i];
        }
    }

    /* Inner shell screening */
    for (int i = 0; i < n_subshells; i++) {
        if (aufbau[i].n >= n && !(aufbau[i].n == n && aufbau[i].l <= 1 && l <= 1))
            continue; /* not inner */
        if (aufbau[i].n == n && aufbau[i].l == l)
            continue; /* self */

        int inner_n = aufbau[i].n;
        int e = electrons[i];

        if (l >= 2) {
            /* d/f: all inner electrons screen by 1.00 */
            S += 1.00f * (float)e;
        } else if (inner_n == n - 1) {
            /* One shell inside: 0.85 */
            S += 0.85f * (float)e;
        } else if (inner_n < n - 1) {
            /* Two+ shells inside: 1.00 */
            S += 1.00f * (float)e;
        }
    }

    float z_eff = (float)Z - S;
    return z_eff > 0.1f ? z_eff : 0.1f;
}

/* ═══════════════════════ DEFAULT PARAMS ═══════════════════════ */

QV_RenderParams quantum_vis_default_params(void) {
    QV_RenderParams p;
    memset(&p, 0, sizeof(p));
    /* Reinhard tone-map + log-compressed opacity */
    p.density_mult   = 50.0f;
    p.gamma          = 0.10f;
    p.emission_scale = 5.0f;
    p.iso_threshold  = 0.001f;
    p.bg_color[0] = 0.00f; p.bg_color[1] = 0.00f; p.bg_color[2] = 0.01f;
    p.step_size      = 0.0f;  /* auto: ~2 * grid spacing */
    p.max_steps      = 1024;   /* Sufficient for 256³ grid high-quality sampling */
    p.color_mode     = 0;     /* physical: phase coloring via signed wavefunction */
    p.output_mode    = 0;     /* |ψ|² probability density */
    p.time           = 0.0f;
    p.jitter_x       = 0.0f;
    p.jitter_y       = 0.0f;
    return p;
}

/* ═══════════════════════ PIPELINE CREATION ═══════════════════════ */

/* Create Pass 1: wavefunction compute pipeline */
static int create_wavefunction_pipeline(QuantumVis *qv) {
    VkDevice dev = qv->device;

    /* Descriptor set layout: binding 0 = density SSBO, binding 1 = orbital SSBO, binding 2 = signed SSBO */
    VkDescriptorSetLayoutBinding bindings[3] = {
        {0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {2, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
    };
    VkDescriptorSetLayoutCreateInfo dslci = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    dslci.bindingCount = 3;
    dslci.pBindings    = bindings;
    if (vkCreateDescriptorSetLayout(dev, &dslci, NULL, &qv->wfDescLayout) != VK_SUCCESS)
        return -1;

    /* Push constant range (matches QuantumPush in shader) */
    VkPushConstantRange pcr = {VK_SHADER_STAGE_COMPUTE_BIT, 0, 32}; /* 8 fields × 4 bytes */
    VkPipelineLayoutCreateInfo plci = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    plci.setLayoutCount         = 1;
    plci.pSetLayouts            = &qv->wfDescLayout;
    plci.pushConstantRangeCount = 1;
    plci.pPushConstantRanges    = &pcr;
    if (vkCreatePipelineLayout(dev, &plci, NULL, &qv->wfPipeLayout) != VK_SUCCESS)
        return -2;

    /* Shader module */
    qv->wfShader = qv_load_shader(dev, "shaders/quantum_wavefunction.comp.spv");
    if (qv->wfShader == VK_NULL_HANDLE) return -3;

    /* Compute pipeline */
    VkComputePipelineCreateInfo cpci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
    cpci.stage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    cpci.stage.stage  = VK_SHADER_STAGE_COMPUTE_BIT;
    cpci.stage.module = qv->wfShader;
    cpci.stage.pName  = "main";
    cpci.layout       = qv->wfPipeLayout;
    if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpci, NULL, &qv->wfPipeline) != VK_SUCCESS)
        return -4;

    /* Descriptor pool + set */
    VkDescriptorPoolSize ps = {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 3};
    VkDescriptorPoolCreateInfo dpci = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    dpci.maxSets       = 1;
    dpci.poolSizeCount = 1;
    dpci.pPoolSizes    = &ps;
    if (vkCreateDescriptorPool(dev, &dpci, NULL, &qv->wfDescPool) != VK_SUCCESS)
        return -5;

    VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    dsai.descriptorPool     = qv->wfDescPool;
    dsai.descriptorSetCount = 1;
    dsai.pSetLayouts        = &qv->wfDescLayout;
    if (vkAllocateDescriptorSets(dev, &dsai, &qv->wfDescSet) != VK_SUCCESS)
        return -6;

    /* Write descriptors */
    VkDescriptorBufferInfo densInfo = {qv->densityBuf, 0, VK_WHOLE_SIZE};
    VkDescriptorBufferInfo orbInfo  = {qv->orbitalBuf, 0, VK_WHOLE_SIZE};
    VkDescriptorBufferInfo sigWfInfo = {qv->signedBuf, 0, VK_WHOLE_SIZE};
    VkWriteDescriptorSet writes[3] = {
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->wfDescSet, 0, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NULL, &densInfo, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->wfDescSet, 1, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NULL, &orbInfo, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->wfDescSet, 2, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NULL, &sigWfInfo, NULL},
    };
    vkUpdateDescriptorSets(dev, 3, writes, 0, NULL);
    return 0;
}

/* Create Pass 2: raymarch pipeline */
static int create_raymarch_pipeline(QuantumVis *qv) {
    VkDevice dev = qv->device;

    /* Layout: 0=outImg, 1=accumImg, 2=density SSBO, 3=signed SSBO, 4=depthImg */
    VkDescriptorSetLayoutBinding bindings[5] = {
        {0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {2, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {3, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {4, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
    };
    VkDescriptorSetLayoutCreateInfo dslci = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    dslci.bindingCount = 5;
    dslci.pBindings    = bindings;
    if (vkCreateDescriptorSetLayout(dev, &dslci, NULL, &qv->rmDescLayout) != VK_SUCCESS)
        return -1;

    /* Push constants: RaymarchPush = 33 fields (see shader, includes jitter) */
    VkPushConstantRange pcr = {VK_SHADER_STAGE_COMPUTE_BIT, 0, 136};
    VkPipelineLayoutCreateInfo plci = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    plci.setLayoutCount         = 1;
    plci.pSetLayouts            = &qv->rmDescLayout;
    plci.pushConstantRangeCount = 1;
    plci.pPushConstantRanges    = &pcr;
    if (vkCreatePipelineLayout(dev, &plci, NULL, &qv->rmPipeLayout) != VK_SUCCESS)
        return -2;

    qv->rmShader = qv_load_shader(dev, "shaders/quantum_raymarch.comp.spv");
    if (qv->rmShader == VK_NULL_HANDLE) return -3;

    VkComputePipelineCreateInfo cpci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
    cpci.stage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    cpci.stage.stage  = VK_SHADER_STAGE_COMPUTE_BIT;
    cpci.stage.module = qv->rmShader;
    cpci.stage.pName  = "main";
    cpci.layout       = qv->rmPipeLayout;
    if (vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpci, NULL, &qv->rmPipeline) != VK_SUCCESS)
        return -4;

    /* Descriptor pool: 3 images + 2 buffers */
    VkDescriptorPoolSize sizes[2] = {
        {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,  3},
        {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 2},
    };
    VkDescriptorPoolCreateInfo dpci = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    dpci.maxSets       = 1;
    dpci.poolSizeCount = 2;
    dpci.pPoolSizes    = sizes;
    if (vkCreateDescriptorPool(dev, &dpci, NULL, &qv->rmDescPool) != VK_SUCCESS)
        return -5;

    VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    dsai.descriptorPool     = qv->rmDescPool;
    dsai.descriptorSetCount = 1;
    dsai.pSetLayouts        = &qv->rmDescLayout;
    if (vkAllocateDescriptorSets(dev, &dsai, &qv->rmDescSet) != VK_SUCCESS)
        return -6;

    /* Write descriptors */
    VkDescriptorImageInfo outInfo  = {VK_NULL_HANDLE, qv->outView,
                                      VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorImageInfo accInfo  = {VK_NULL_HANDLE, qv->accumView,
                                      VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorImageInfo depInfo  = {VK_NULL_HANDLE, qv->depthView,
                                      VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorBufferInfo densInfo = {qv->densityBuf, 0, VK_WHOLE_SIZE};
    VkDescriptorBufferInfo sigInfo  = {qv->signedBuf,  0, VK_WHOLE_SIZE};

    VkWriteDescriptorSet writes[5] = {
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->rmDescSet, 0, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &outInfo, NULL, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->rmDescSet, 1, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &accInfo, NULL, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->rmDescSet, 2, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NULL, &densInfo, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->rmDescSet, 3, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, NULL, &sigInfo, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, qv->rmDescSet, 4, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &depInfo, NULL, NULL},
    };
    vkUpdateDescriptorSets(dev, 5, writes, 0, NULL);
    return 0;
}

/* ═══════════════════════ PUBLIC API ═══════════════════════ */

int quantum_vis_init(QuantumVis *qv,
                     VkPhysicalDevice phys, VkDevice dev,
                     uint32_t queueFamilyIdx,
                     int imageW, int imageH) {
    memset(qv, 0, sizeof(*qv));
    qv->device     = dev;
    qv->physDevice = phys;
    qv->imageW     = imageW;
    qv->imageH     = imageH;
    if (qv->gridDim <= 0) qv->gridDim = QV_DEFAULT_GRID_DIM;
    qv->boxHalf    = QV_DEFAULT_BOX_HALF;
    qv->params     = quantum_vis_default_params();
    qv->needsGridUpdate = 1;

    VkDeviceSize gridSize = (VkDeviceSize)qv->gridDim * qv->gridDim * qv->gridDim * sizeof(float);
    VkDeviceSize orbSize  = QV_MAX_ORBITALS * sizeof(QV_OrbitalConfig);

    /* Create GPU buffers */
    int rc;
    rc = qv_create_buffer(phys, dev, gridSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &qv->densityBuf, &qv->densityMem);
    if (rc) { fprintf(stderr, "[QV] density buffer failed: %d\n", rc); return rc; }

    rc = qv_create_buffer(phys, dev, gridSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &qv->signedBuf, &qv->signedMem);
    if (rc) { fprintf(stderr, "[QV] signed buffer failed: %d\n", rc); return rc; }

    /* Orbital config buffer: host-visible for CPU updates */
    rc = qv_create_buffer(phys, dev, orbSize,
            VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &qv->orbitalBuf, &qv->orbitalMem);
    if (rc) { fprintf(stderr, "[QV] orbital buffer failed: %d\n", rc); return rc; }

    /* Output + accumulation images (rgba32f) */
    VkImageUsageFlags img_usage = VK_IMAGE_USAGE_STORAGE_BIT
                                | VK_IMAGE_USAGE_TRANSFER_SRC_BIT
                                | VK_IMAGE_USAGE_TRANSFER_DST_BIT
                                | VK_IMAGE_USAGE_SAMPLED_BIT;
    rc = qv_create_image_2d(phys, dev, imageW, imageH,
            VK_FORMAT_R32G32B32A32_SFLOAT, img_usage,
            &qv->outImage, &qv->outView, &qv->outMem);
    if (rc) { fprintf(stderr, "[QV] out image failed: %d\n", rc); return rc; }

    rc = qv_create_image_2d(phys, dev, imageW, imageH,
            VK_FORMAT_R32G32B32A32_SFLOAT, img_usage,
            &qv->accumImage, &qv->accumView, &qv->accumMem);
    if (rc) { fprintf(stderr, "[QV] accum image failed: %d\n", rc); return rc; }

    /* Depth image for DLSS temporal reprojection (R32_SFLOAT) */
    rc = qv_create_image_2d(phys, dev, imageW, imageH,
            VK_FORMAT_R32_SFLOAT, img_usage,
            &qv->depthImage, &qv->depthView, &qv->depthMem);
    if (rc) { fprintf(stderr, "[QV] depth image failed: %d\n", rc); return rc; }

    /* Readback buffer for headless output */
    VkDeviceSize rbSize = (VkDeviceSize)imageW * imageH * 4 * sizeof(float);
    rc = qv_create_buffer(phys, dev, rbSize,
            VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &qv->readbackBuf, &qv->readbackMem);
    if (rc) { fprintf(stderr, "[QV] readback buffer failed: %d\n", rc); return rc; }

    /* Command pool + buffer */
    VkCommandPoolCreateInfo cpci = {VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
    cpci.flags            = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = queueFamilyIdx;
    if (vkCreateCommandPool(dev, &cpci, NULL, &qv->cmdPool) != VK_SUCCESS) return -10;

    VkCommandBufferAllocateInfo cbai = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    cbai.commandPool        = qv->cmdPool;
    cbai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    if (vkAllocateCommandBuffers(dev, &cbai, &qv->cmdBuf) != VK_SUCCESS) return -11;

    /* Create compute pipelines */
    rc = create_wavefunction_pipeline(qv);
    if (rc) { fprintf(stderr, "[QV] wavefunction pipeline failed: %d\n", rc); return rc; }

    rc = create_raymarch_pipeline(qv);
    if (rc) { fprintf(stderr, "[QV] raymarch pipeline failed: %d\n", rc); return rc; }

    printf("[QV] Quantum visualization initialized: grid=%d³, box=%.1f a₀, image=%dx%d\n",
           qv->gridDim, qv->boxHalf, imageW, imageH);
    return 0;
}

/* ─────────── Orbital configuration ─────────── */

void quantum_vis_set_hydrogen(QuantumVis *qv, int n, int l, int m) {
    qv->numOrbitals = 1;
    memset(qv->orbitals, 0, sizeof(qv->orbitals));
    qv->orbitals[0].n          = n;
    qv->orbitals[0].l          = l;
    qv->orbitals[0].m          = m;
    qv->orbitals[0].Z_eff      = 1.0f; /* hydrogen */
    qv->orbitals[0].occupation = 1.0f;
    qv->orbitals[0].phase_t    = 0.0f;

    /* Adjust box size based on orbital extent (~2n² a₀ for hydrogen) */
    qv->boxHalf = 2.0f * (float)(n * n) + 5.0f;

    /* Auto-scale density/emission for higher n: the peak |ψ|² falls as
       ~(Z/n)³, so we need proportionally more amplification.  Use n=1 as
       the baseline (density_mult=500, emission_scale=8). */
    float n3 = (float)(n * n * n);
    /* Scale density amplification with n³ (peak |ψ|² falls as ~1/n³).
     * Cap low-n to avoid total saturation, but keep them bright enough
     * to clearly glow — especially 2p whose peak |ψ|² is very small. */
    float dm_raw = 100.0f * n3;
    if (n <= 1) dm_raw = 55.0f;       /* 1s: bright translucent sphere (~40% opacity) */
    else if (n <= 2) dm_raw = 500.0f;  /* 2s/2p: visible lobes, 2p peak |ψ|² ≈ 0.005 */
    qv->params.density_mult   = dm_raw;
    qv->params.emission_scale = 4.0f;
    qv->params.gamma          = 0.08f;   /* translucent glowing cloud */
    qv->params.color_mode     = 1;       /* warm palette for hydrogen */

    qv->needsGridUpdate = 1;
    printf("[QV] Set hydrogen orbital: n=%d l=%d m=%d (box=%.1f a₀, density_mult=%.0f)\n",
           n, l, m, qv->boxHalf, qv->params.density_mult);
}

void quantum_vis_set_atom(QuantumVis *qv, int Z) {
    /* Aufbau filling for Z electrons */
    static const struct { int n, l, max_e; } aufbau[] = {
        {1,0,2}, {2,0,2}, {2,1,6}, {3,0,2}, {3,1,6},
        {4,0,2}, {3,2,10},{4,1,6}, {5,0,2}, {4,2,10},
        {5,1,6}
    };
    int n_sub = (int)(sizeof(aufbau)/sizeof(aufbau[0]));

    qv->numOrbitals = 0;
    memset(qv->orbitals, 0, sizeof(qv->orbitals));

    int remaining = Z;
    for (int i = 0; i < n_sub && remaining > 0 && qv->numOrbitals < QV_MAX_ORBITALS; i++) {
        int n = aufbau[i].n;
        int l = aufbau[i].l;
        int e_in_sub = remaining < aufbau[i].max_e ? remaining : aufbau[i].max_e;
        remaining -= e_in_sub;

        float z_eff = quantum_slater_z_eff(Z, n, l);

        /* Distribute electrons across m values: -l to +l */
        /* For visualization: each m gets separate orbital entry */
        int m_values = 2 * l + 1;
        float e_per_m = (float)e_in_sub / (float)m_values;

        for (int m = -l; m <= l && qv->numOrbitals < QV_MAX_ORBITALS; m++) {
            float occ = e_per_m;
            if (occ < 0.01f) continue;

            QV_OrbitalConfig *oc = &qv->orbitals[qv->numOrbitals++];
            oc->n          = n;
            oc->l          = l;
            oc->m          = m;
            oc->Z_eff      = z_eff;
            oc->occupation = occ;
            oc->phase_t    = 0.0f;
        }
    }

    /* Compute box size: largest orbital extent */
    int max_n = 1;
    float min_z_eff = 1.0f;
    for (int i = 0; i < qv->numOrbitals; i++) {
        if (qv->orbitals[i].n > max_n) max_n = qv->orbitals[i].n;
        if (qv->orbitals[i].Z_eff < min_z_eff) min_z_eff = qv->orbitals[i].Z_eff;
    }
    /* Box sized for outermost orbital: r_max ~ n²/Z_eff (in a₀) */
    float outer_r = (float)(max_n * max_n) / (min_z_eff > 0.1f ? min_z_eff : 0.1f);
    qv->boxHalf = outer_r * 2.0f + 5.0f;
    if (qv->boxHalf < 10.0f) qv->boxHalf = 10.0f;
    if (qv->boxHalf > 80.0f) qv->boxHalf = 80.0f;

    /* Auto-scale density/emission for multi-electron atoms.
       Total |ψ|² near the nucleus ∝ Z_eff³ (inner 1s dominates).
       We use very low density multiplier + double-log compression
       in the shader to keep the cloud translucent. */
    qv->params.density_mult   = 5.0f;
    qv->params.emission_scale = 5.0f;
    qv->params.gamma          = 0.04f;  /* thin translucent cloud — shows shell structure */
    qv->params.color_mode     = 0;      /* blue-purple quantum chemistry palette */

    qv->needsGridUpdate = 1;
    printf("[QV] Atom Z=%d: %d orbitals, box=%.1f a₀, density_mult=%.0f\n",
           Z, qv->numOrbitals, qv->boxHalf, qv->params.density_mult);
}

void quantum_vis_set_orbitals(QuantumVis *qv,
                              const QV_OrbitalConfig *orbs, int count) {
    if (count > QV_MAX_ORBITALS) count = QV_MAX_ORBITALS;
    qv->numOrbitals = count;
    memcpy(qv->orbitals, orbs, (size_t)count * sizeof(QV_OrbitalConfig));
    qv->needsGridUpdate = 1;
}

/* ─────────── Dispatch ─────────── */

static void upload_orbitals(QuantumVis *qv) {
    void *mapped;
    vkMapMemory(qv->device, qv->orbitalMem, 0,
                QV_MAX_ORBITALS * sizeof(QV_OrbitalConfig), 0, &mapped);
    memcpy(mapped, qv->orbitals, QV_MAX_ORBITALS * sizeof(QV_OrbitalConfig));
    vkUnmapMemory(qv->device, qv->orbitalMem);
}

/* Push constants struct for wavefunction shader — must match GLSL layout */
typedef struct {
    int   gridDim;
    int   numOrbitals;
    float boxHalf;
    float isoValue;
    int   outputMode;
    float time;
    float densityScale;
    int   enableSpin;
} QV_WfPush;

/* Push constants for raymarch shader — must match GLSL layout */
typedef struct {
    int   W, H, frame, gridDim;
    float boxHalf, stepSize;
    int   maxSteps;
    float densityMult, gamma;
    int   colorMode;
    float camPosX, camPosY, camPosZ;
    float camFwdX, camFwdY, camFwdZ;
    float camRightX, camRightY, camRightZ;
    float camUpX, camUpY, camUpZ;
    float fov;
    float bgR, bgG, bgB;
    float isoThreshold;
    int   useSignedGrid;
    float emissionScale;
    float alpha;
    int   resetAccum;
    float jitterX;
    float jitterY;
} QV_RmPush;

int quantum_vis_dispatch(QuantumVis *qv, VkQueue queue,
                         const QV_Camera *cam, int frame) {
    VkDevice dev = qv->device;
    VkCommandBuffer cmd = qv->cmdBuf;

    /* Upload orbital configs if changed */
    if (qv->needsGridUpdate) {
        upload_orbitals(qv);
    }

    vkResetCommandBuffer(cmd, 0);
    VkCommandBufferBeginInfo bi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cmd, &bi);

    /* ─── Pass 1: Evaluate wavefunction on 3D grid ─── */
    if (qv->needsGridUpdate) {
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, qv->wfPipeline);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE,
                                qv->wfPipeLayout, 0, 1, &qv->wfDescSet, 0, NULL);

        QV_WfPush wfpc;
        wfpc.gridDim      = qv->gridDim;
        wfpc.numOrbitals   = qv->numOrbitals;
        wfpc.boxHalf       = qv->boxHalf;
        wfpc.isoValue      = qv->params.iso_threshold;
        wfpc.outputMode    = qv->params.output_mode;
        wfpc.time          = qv->params.time;
        wfpc.densityScale  = 1.0f; /* raw density; scaling in raymarch */
        wfpc.enableSpin    = 1;
        vkCmdPushConstants(cmd, qv->wfPipeLayout, VK_SHADER_STAGE_COMPUTE_BIT,
                           0, sizeof(wfpc), &wfpc);

        /* Dispatch: gridDim³ / (8×8×8) workgroups */
        uint32_t groups = ((uint32_t)qv->gridDim + 7) / 8;
        vkCmdDispatch(cmd, groups, groups, groups);

        /* Barrier: grid SSBO write → read */
        VkMemoryBarrier mb = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cmd,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 1, &mb, 0, NULL, 0, NULL);

        qv->needsGridUpdate = 0;
    }

    /* ─── Transition images to GENERAL layout (first frame) ─── */
    if (frame == 0) {
        VkImageMemoryBarrier imb[3];
        memset(imb, 0, sizeof(imb));
        for (int i = 0; i < 3; i++) {
            imb[i].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            imb[i].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            imb[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
            imb[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imb[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            imb[i].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            imb[i].subresourceRange.levelCount = 1;
            imb[i].subresourceRange.layerCount = 1;
            imb[i].dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
        }
        imb[0].image = qv->outImage;
        imb[1].image = qv->accumImage;
        imb[2].image = qv->depthImage;
        vkCmdPipelineBarrier(cmd,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 0, NULL, 0, NULL, 3, imb);
    }

    /* ─── Pass 2: Volume raymarch ─── */
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, qv->rmPipeline);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE,
                            qv->rmPipeLayout, 0, 1, &qv->rmDescSet, 0, NULL);

    QV_RmPush rmpc;
    rmpc.W            = qv->imageW;
    rmpc.H            = qv->imageH;
    rmpc.frame        = frame;
    rmpc.gridDim      = qv->gridDim;
    rmpc.boxHalf      = qv->boxHalf;
    rmpc.stepSize     = qv->params.step_size;
    rmpc.maxSteps     = qv->params.max_steps;
    rmpc.densityMult  = qv->params.density_mult;
    rmpc.gamma        = qv->params.gamma;
    rmpc.colorMode    = qv->params.color_mode;
    rmpc.camPosX      = cam->pos[0];
    rmpc.camPosY      = cam->pos[1];
    rmpc.camPosZ      = cam->pos[2];
    rmpc.camFwdX      = cam->fwd[0];
    rmpc.camFwdY      = cam->fwd[1];
    rmpc.camFwdZ      = cam->fwd[2];
    rmpc.camRightX    = cam->right[0];
    rmpc.camRightY    = cam->right[1];
    rmpc.camRightZ    = cam->right[2];
    rmpc.camUpX       = cam->up[0];
    rmpc.camUpY       = cam->up[1];
    rmpc.camUpZ       = cam->up[2];
    rmpc.fov          = cam->fov_y;
    rmpc.bgR          = qv->params.bg_color[0];
    rmpc.bgG          = qv->params.bg_color[1];
    rmpc.bgB          = qv->params.bg_color[2];
    rmpc.isoThreshold = qv->params.iso_threshold;
    /* Enable signed grid for phase coloring (mode 2), nuclear (mode 4), thermal (mode 5), RBMK (mode 6), or atomic fission (mode 7) */
    rmpc.useSignedGrid = (qv->params.output_mode != 0 || qv->params.color_mode == 2 || qv->params.color_mode == 4 || qv->params.color_mode == 5 || qv->params.color_mode == 6 || qv->params.color_mode == 7) ? 1 : 0;
    rmpc.emissionScale = qv->params.emission_scale;
    rmpc.alpha         = 0.0f; /* running average */
    rmpc.resetAccum    = (frame == 0) ? 1 : 0;
    rmpc.jitterX       = qv->params.jitter_x;
    rmpc.jitterY       = qv->params.jitter_y;

    vkCmdPushConstants(cmd, qv->rmPipeLayout, VK_SHADER_STAGE_COMPUTE_BIT,
                       0, sizeof(rmpc), &rmpc);

    /* Dispatch: ceil(W/16) × ceil(H/16) workgroups */
    vkCmdDispatch(cmd, ((uint32_t)qv->imageW + 15) / 16,
                       ((uint32_t)qv->imageH + 15) / 16, 1);

    vkEndCommandBuffer(cmd);

    qv_submit_and_wait(dev, queue, cmd);
    return 0;
}

/* ─────────── Readback ─────────── */

int quantum_vis_readback(QuantumVis *qv, VkQueue queue,
                         float *rgba_out, int w, int h) {
    VkDevice dev = qv->device;
    VkCommandBuffer cmd = qv->cmdBuf;

    vkResetCommandBuffer(cmd, 0);
    VkCommandBufferBeginInfo bi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cmd, &bi);

    /* Barrier: image → transfer src */
    VkImageMemoryBarrier imb = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    imb.oldLayout     = VK_IMAGE_LAYOUT_GENERAL;
    imb.newLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    imb.image         = qv->outImage;
    imb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    imb.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    imb.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    imb.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    imb.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    imb.subresourceRange.levelCount = 1;
    imb.subresourceRange.layerCount = 1;
    vkCmdPipelineBarrier(cmd,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0, 0, NULL, 0, NULL, 1, &imb);

    /* Copy image → buffer */
    VkBufferImageCopy region = {0};
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.layerCount = 1;
    region.imageExtent = (VkExtent3D){(uint32_t)w, (uint32_t)h, 1};
    vkCmdCopyImageToBuffer(cmd, qv->outImage,
                           VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                           qv->readbackBuf, 1, &region);

    /* Barrier back to GENERAL */
    imb.oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    imb.newLayout     = VK_IMAGE_LAYOUT_GENERAL;
    imb.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    imb.dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    vkCmdPipelineBarrier(cmd,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        0, 0, NULL, 0, NULL, 1, &imb);

    vkEndCommandBuffer(cmd);
    qv_submit_and_wait(dev, queue, cmd);

    /* Map and copy out */
    void *mapped;
    vkMapMemory(dev, qv->readbackMem, 0, (VkDeviceSize)w * h * 16, 0, &mapped);
    memcpy(rgba_out, mapped, (size_t)w * h * 4 * sizeof(float));
    vkUnmapMemory(dev, qv->readbackMem);

    return 0;
}

/* ─────────── Cleanup ─────────── */

void quantum_vis_free(QuantumVis *qv, VkDevice dev) {
    vkDeviceWaitIdle(dev);

    /* Pipelines */
    if (qv->wfPipeline)    vkDestroyPipeline(dev, qv->wfPipeline, NULL);
    if (qv->wfPipeLayout)  vkDestroyPipelineLayout(dev, qv->wfPipeLayout, NULL);
    if (qv->wfDescPool)    vkDestroyDescriptorPool(dev, qv->wfDescPool, NULL);
    if (qv->wfDescLayout)  vkDestroyDescriptorSetLayout(dev, qv->wfDescLayout, NULL);
    if (qv->wfShader)      vkDestroyShaderModule(dev, qv->wfShader, NULL);

    if (qv->rmPipeline)    vkDestroyPipeline(dev, qv->rmPipeline, NULL);
    if (qv->rmPipeLayout)  vkDestroyPipelineLayout(dev, qv->rmPipeLayout, NULL);
    if (qv->rmDescPool)    vkDestroyDescriptorPool(dev, qv->rmDescPool, NULL);
    if (qv->rmDescLayout)  vkDestroyDescriptorSetLayout(dev, qv->rmDescLayout, NULL);
    if (qv->rmShader)      vkDestroyShaderModule(dev, qv->rmShader, NULL);

    /* Buffers */
    if (qv->densityBuf)    { vkDestroyBuffer(dev, qv->densityBuf, NULL); vkFreeMemory(dev, qv->densityMem, NULL); }
    if (qv->signedBuf)     { vkDestroyBuffer(dev, qv->signedBuf, NULL);  vkFreeMemory(dev, qv->signedMem, NULL); }
    if (qv->orbitalBuf)    { vkDestroyBuffer(dev, qv->orbitalBuf, NULL); vkFreeMemory(dev, qv->orbitalMem, NULL); }
    if (qv->readbackBuf)   { vkDestroyBuffer(dev, qv->readbackBuf, NULL);vkFreeMemory(dev, qv->readbackMem, NULL); }

    /* Images */
    if (qv->outView)       vkDestroyImageView(dev, qv->outView, NULL);
    if (qv->outImage)      { vkDestroyImage(dev, qv->outImage, NULL); vkFreeMemory(dev, qv->outMem, NULL); }
    if (qv->accumView)     vkDestroyImageView(dev, qv->accumView, NULL);
    if (qv->accumImage)    { vkDestroyImage(dev, qv->accumImage, NULL); vkFreeMemory(dev, qv->accumMem, NULL); }
    if (qv->depthView)     vkDestroyImageView(dev, qv->depthView, NULL);
    if (qv->depthImage)    { vkDestroyImage(dev, qv->depthImage, NULL); vkFreeMemory(dev, qv->depthMem, NULL); }

    /* Command pool */
    if (qv->cmdPool)       vkDestroyCommandPool(dev, qv->cmdPool, NULL);

    memset(qv, 0, sizeof(*qv));
}
