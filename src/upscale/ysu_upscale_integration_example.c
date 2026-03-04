/* ysu_upscale_integration_example.c — Reference integration of YSU Neural Upscale
 *
 * This is NOT a standalone executable. It shows the canonical integration
 * pattern for embedding the upscale system into an existing Vulkan renderer.
 *
 * Compile: included by your renderer .c file, or adapt as needed.
 */

#include "ysu_upscale.h"
#include <stdio.h>
#include <stdlib.h>

/* ═══════════════════════════════════════════════════════════════════
 *  Example: engine-side render loop integration
 * ═══════════════════════════════════════════════════════════════════ */

/*
 * Assumptions:
 *   - You have a working Vulkan device, physical device, and queue
 *   - Your renderer produces: color (RGBA16F), depth (R32F), motion vectors (RG16F)
 *   - All at internal (low-res) resolution
 *   - You have a display target image at output (high-res) resolution
 */

typedef struct MyRenderer {
    VkDevice         device;
    VkPhysicalDevice phys_device;
    VkQueue          graphics_queue;
    VkQueue          compute_queue;     /* can be same as graphics */
    uint32_t         graphics_family;
    uint32_t         compute_family;

    /* Per-frame G-buffer outputs (low-res) */
    VkImage          color_image;
    VkImageView      color_view;
    VkImage          depth_image;
    VkImageView      depth_view;
    VkImage          mv_image;
    VkImageView      mv_view;

    /* Display target (high-res, e.g. swapchain image view or offscreen) */
    VkImage          display_image;
    VkImageView      display_view;

    /* Upscale system */
    YsuUpscaleCtx    upscale;

    /* Frame tracking */
    uint32_t         frame_index;
    uint32_t         display_w, display_h;

    YsuUpscaleQuality quality_preset;
} MyRenderer;


/* ─── Helper: load SPIR-V from file ─── */
static uint32_t* load_spirv(const char* path, size_t* out_size) {
    FILE* f = fopen(path, "rb");
    if (!f) { *out_size = 0; return NULL; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0) { fclose(f); *out_size = 0; return NULL; }
    uint32_t* data = (uint32_t*)malloc((size_t)sz);
    fread(data, 1, (size_t)sz, f);
    fclose(f);
    *out_size = (size_t)sz;
    return data;
}


/* ═══════════════════════════════════════════════════════════════════
 *  Step 1: Initialize upscale system (once at startup)
 * ═══════════════════════════════════════════════════════════════════ */

VkResult my_init_upscale(MyRenderer* r) {
    /* Load compiled compute shaders */
    size_t sz_reproj, sz_neural, sz_sharpen;
    uint32_t* spv_reproj  = load_spirv("shaders/upscale_reproj.spv",  &sz_reproj);
    uint32_t* spv_neural  = load_spirv("shaders/upscale_neural.spv",  &sz_neural);
    uint32_t* spv_sharpen = load_spirv("shaders/upscale_sharpen.spv", &sz_sharpen);

    YsuUpscaleInitInfo info = {
        .device              = r->device,
        .phys_device         = r->phys_device,
        .queue_family_index  = r->compute_family,
        .compute_queue       = r->compute_queue,
        .max_display_w       = 3840,   /* 4K max */
        .max_display_h       = 2160,
        .weight_file_path    = "models/ysu_upscale_v1.weights",  /* NULL for fallback */

        .spv_reproj       = spv_reproj,
        .spv_reproj_size  = sz_reproj,
        .spv_neural       = spv_neural,
        .spv_neural_size  = sz_neural,
        .spv_sharpen      = spv_sharpen,
        .spv_sharpen_size = sz_sharpen,

        .allocator = NULL,
    };

    VkResult result = ysu_upscale_init(&r->upscale, &info);

    /* Free host-side SPIR-V copies (GPU now owns the shader modules) */
    free(spv_reproj);
    free(spv_neural);
    free(spv_sharpen);

    return result;
}


/* ═══════════════════════════════════════════════════════════════════
 *  Step 2: Per-frame projection matrix jitter
 *
 *  Apply BEFORE rendering the low-res frame. The jitter must
 *  be applied to the projection matrix used for ray generation or
 *  rasterization. Motion vectors must NOT include the jitter.
 * ═══════════════════════════════════════════════════════════════════ */

void my_apply_jitter(MyRenderer* r, float proj_matrix[16]) {
    /* Get resolution at current quality preset */
    float scale = ysu_upscale_quality_factor(r->quality_preset);
    uint32_t w_lo = (uint32_t)(r->display_w * scale);
    uint32_t h_lo = (uint32_t)(r->display_h * scale);

    /* Halton(2,3) jitter with 16-phase cycle */
    YsuJitter j = ysu_upscale_jitter(r->frame_index);

    /* Apply jitter to projection matrix as NDC translation:
     *
     *   P_jittered[2][0] += 2 * jitter_x / w_lo
     *   P_jittered[2][1] += 2 * jitter_y / h_lo
     *
     * This is equivalent to a sub-pixel camera shift.
     * For column-major (OpenGL/Vulkan convention):               */

    proj_matrix[8]  += 2.0f * j.x / (float)w_lo;  /* [2][0] in col-major */
    proj_matrix[9]  += 2.0f * j.y / (float)h_lo;  /* [2][1] in col-major */

    /* For ray-traced renderers, offset the ray origin by:
     *
     *   ray.origin += camera_right * (jitter_x / w_lo) * pixel_width
     *               + camera_up    * (jitter_y / h_lo) * pixel_height
     *
     * where pixel_width/height are in world units at the near plane. */
}


/* ═══════════════════════════════════════════════════════════════════
 *  Step 3: Motion vector generation
 *
 *  Critical: motion vectors must be in SCREEN-SPACE LOW-RES PIXEL
 *  COORDINATES (not UV, not NDC, not world-space).
 *
 *  MV(p) = screen_pos_previous_frame(p) − screen_pos_current_frame(p)
 *
 *  Sign convention: positive X = rightward motion, positive Y = downward.
 *  The jitter offset must NOT be included in motion vectors.
 * ═══════════════════════════════════════════════════════════════════
 *
 * For each pixel in the G-buffer pass:
 *
 *   // In vertex/fragment shader:
 *   vec2 pos_curr = (gl_Position.xy / gl_Position.w) * 0.5 + 0.5;   // current NDC→UV
 *   vec2 pos_prev = (prev_clip.xy / prev_clip.w) * 0.5 + 0.5;       // previous NDC→UV
 *   // Convert to pixel coordinates:
 *   pos_curr *= vec2(w_lo, h_lo);
 *   pos_prev *= vec2(w_lo, h_lo);
 *   // Remove jitter from current position (motion should not include jitter):
 *   pos_curr -= jitter;
 *   motion_vector = pos_prev - pos_curr;
 *
 * For ray-traced: compute MV from current and previous frame world positions:
 *
 *   world_pos = ray.origin + ray.direction * hit_t;
 *   prev_clip = prev_VP * vec4(world_pos, 1.0);
 *   // same as above
 */


/* ═══════════════════════════════════════════════════════════════════
 *  Step 4: Execute upscale in command buffer
 * ═══════════════════════════════════════════════════════════════════ */

void my_render_frame(MyRenderer* r, VkCommandBuffer cmd) {
    /* --- Phase A: Render low-res scene (your existing renderer) --- */
    /* my_render_scene(r, cmd);  // produces color_view, depth_view, mv_view */

    /* --- Phase B: Transition inputs to SHADER_READ --- */
    /* (In practice, your render pass already outputs these correctly.
     *  Ensure color/depth/mv images are in SHADER_READ_ONLY_OPTIMAL
     *  before calling the upscale pass.)                              */

    /* --- Phase C: Compute resolution and jitter --- */
    float scale = ysu_upscale_quality_factor(r->quality_preset);
    uint32_t w_lo = (uint32_t)(r->display_w * scale);
    uint32_t h_lo = (uint32_t)(r->display_h * scale);
    YsuJitter jitter = ysu_upscale_jitter(r->frame_index);

    /* --- Phase D: Fill frame params and execute --- */
    YsuUpscaleFrameParams params = {
        .color_lo   = r->color_view,
        .depth_lo   = r->depth_view,
        .motion_vec = r->mv_view,
        .output_hi  = r->display_view,

        .w_lo = w_lo,
        .h_lo = h_lo,
        .w_hi = r->display_w,
        .h_hi = r->display_h,

        .jitter      = jitter,
        .frame_index = r->frame_index,
        .dt          = 1.0f / 60.0f,  /* assume 60fps; use actual dt */

        .near_plane = 0.1f,
        .far_plane  = 1000.0f,

        .sharpness   = 0.2f,     /* or 0.0 to disable */
        .clamp_gamma = 1.0f,     /* default AABB extent */
        .debug_mode  = 0,
    };

    /* Update descriptor sets (only needed when image views change) */
    ysu_upscale_update_descriptors(&r->upscale, &params);

    /* Record 3-pass upscale pipeline */
    ysu_upscale_execute(&r->upscale, cmd, &params);

    r->frame_index++;
}


/* ═══════════════════════════════════════════════════════════════════
 *  Step 5: Dynamic resolution scaling (optional)
 *
 *  Change quality preset at runtime based on frame time budget.
 *  The upscale system handles variable w_lo/h_lo per frame —
 *  no reinitialization needed.
 * ═══════════════════════════════════════════════════════════════════ */

void my_dynamic_resolution_update(MyRenderer* r, float frame_time_ms) {
    /* Target budget: 16.67ms for 60fps */
    const float target_ms = 16.67f;
    const float headroom  = 1.5f;   /* ms of headroom for OS/compositor */

    float budget = target_ms - headroom;

    if (frame_time_ms > budget * 1.2f && r->quality_preset < YSU_UPSCALE_QUALITY_ULTRA_PERF) {
        /* Over budget by 20%+ — step down quality (lower internal res) */
        r->quality_preset = (YsuUpscaleQuality)(r->quality_preset - 1);
        fprintf(stderr, "[DRS] Stepped down to quality %d (%.1fms)\n",
                r->quality_preset, frame_time_ms);
    } else if (frame_time_ms < budget * 0.7f && r->quality_preset < YSU_UPSCALE_QUALITY_ULTRA) {
        /* Under budget by 30%+ — step up quality (higher internal res) */
        r->quality_preset = (YsuUpscaleQuality)(r->quality_preset + 1);
        fprintf(stderr, "[DRS] Stepped up to quality %d (%.1fms)\n",
                r->quality_preset, frame_time_ms);
    }

    /* After changing quality_preset, the next frame will use the new w_lo/h_lo.
     * You must resize your G-buffer render targets to match. */
}


/* ═══════════════════════════════════════════════════════════════════
 *  Step 6: Async compute integration (advanced)
 *
 *  For maximum performance, overlap the upscale work with the next
 *  frame's geometry/rasterization. Requires separate graphics and
 *  compute queues with semaphore synchronization.
 * ═══════════════════════════════════════════════════════════════════ */

/*
 * TIMELINE:
 *
 * Frame N:
 *   Graphics Queue: [Render G-Buffer N] ──signal(sem_render_done)──▶ [Render G-Buffer N+1]
 *   Compute Queue:            wait(sem_render_done)──▶ [Upscale N] ──signal(sem_upscale_done)──▶
 *   Present Queue:                                        wait(sem_upscale_done)──▶ [Present N]
 *
 * Implementation:
 *
 *   // After recording G-buffer commands:
 *   VkSubmitInfo gfx_submit = {
 *       .commandBufferCount = 1,
 *       .pCommandBuffers    = &gfx_cmd,
 *       .signalSemaphoreCount = 1,
 *       .pSignalSemaphores   = &sem_render_done,
 *   };
 *   vkQueueSubmit(graphics_queue, 1, &gfx_submit, VK_NULL_HANDLE);
 *
 *   // Upscale on compute queue:
 *   VkPipelineStageFlags wait_stage = VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
 *   VkSubmitInfo compute_submit = {
 *       .waitSemaphoreCount   = 1,
 *       .pWaitSemaphores     = &sem_render_done,
 *       .pWaitDstStageMask   = &wait_stage,
 *       .commandBufferCount  = 1,
 *       .pCommandBuffers     = &compute_cmd,   // recorded with ysu_upscale_execute
 *       .signalSemaphoreCount = 1,
 *       .pSignalSemaphores   = &sem_upscale_done,
 *   };
 *   vkQueueSubmit(compute_queue, 1, &compute_submit, VK_NULL_HANDLE);
 *
 *   // Present waits on upscale completion:
 *   VkPresentInfoKHR present = {
 *       .waitSemaphoreCount = 1,
 *       .pWaitSemaphores    = &sem_upscale_done,
 *       ...
 *   };
 *   vkQueuePresentKHR(present_queue, &present);
 *
 * NOTE: When using different queue families for graphics and compute,
 * you must insert queue ownership transfer barriers for the shared
 * images (color_lo, depth_lo, mv). The current ysu_upscale.c assumes
 * same-family (VK_SHARING_MODE_EXCLUSIVE). For cross-family, modify
 * the barrier's srcQueueFamilyIndex/dstQueueFamilyIndex.
 */


/* ═══════════════════════════════════════════════════════════════════
 *  Step 7: Cleanup
 * ═══════════════════════════════════════════════════════════════════ */

void my_destroy_upscale(MyRenderer* r) {
    ysu_upscale_destroy(&r->upscale);
}


/* ═══════════════════════════════════════════════════════════════════
 *  Appendix: Training data collector
 *
 *  This is a sketch for generating paired training data from
 *  the engine at both low-res and high-res. See architecture doc
 *  for full details.
 * ═══════════════════════════════════════════════════════════════════ */

/*
 * For each training sample:
 *
 * 1. Set high SPP (≥256), disable jitter, render at 4K → ground_truth.exr
 * 2. For each of N jitter phases (e.g., 8 consecutive Halton indices):
 *    a. Apply jitter J_i to projection
 *    b. Render at 1080p with low SPP (4–16) → input_i.exr
 *    c. Record depth_i.exr, mv_i.exr, obj_id_i.exr
 * 3. Save as training pair:
 *    { inputs: [input_0..input_7], ground_truth, depths, mvs, jitters }
 *
 * Training script (Python/PyTorch):
 *
 *   for epoch in range(300):
 *       for batch in dataloader:
 *           # batch contains: low_res (BxCxH_lo×W_lo), history, mv, depth,
 *           #                 jitter, confidence, ground_truth (Bx3×H_hi×W_hi)
 *
 *           # Forward: simulate temporal accumulation pipeline
 *           reproj = warp(history, mv)
 *           clamped = aabb_clamp(reproj, low_res)
 *           feat = assemble_features(low_res, clamped, mv, depth, jitter, confidence)
 *           pred = model(feat) + F.interpolate(low_res, scale_factor=r, mode='bilinear')
 *
 *           # Loss
 *           loss_char = charbonnier(pred, ground_truth, eps=1e-3)
 *           loss_perc = perceptual_loss(pred, ground_truth)   # frozen VGG features
 *           loss_temp = temporal_consistency(pred, prev_pred, mv)
 *           loss = loss_char + 0.1 * loss_perc + 0.05 * loss_temp
 *
 *           optimizer.zero_grad()
 *           loss.backward()
 *           torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
 *           optimizer.step()
 *
 * Export:
 *   weights = model.half().state_dict()  # FP16
 *   with open('ysu_upscale_v1.weights', 'wb') as f:
 *       header = struct.pack('<IIII', 0x5955574E, 1, total_params, 0)
 *       f.write(header)
 *       for name in sorted(weights.keys()):
 *           f.write(weights[name].cpu().numpy().tobytes())
 */
