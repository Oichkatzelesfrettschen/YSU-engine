/* quantum_volume.h — Public API for quantum wavefunction visualization
 *
 * Two-pass GPU pipeline:
 *   Pass 1: quantum_wavefunction.comp evaluates |ψ|² on a 3D grid (SSBO)
 *   Pass 2: quantum_raymarch.comp raymarches the grid → 2D image
 *
 * Usage:
 *   QuantumVis qv;
 *   quantum_vis_init(&qv, phys, dev, queueFamilyIdx, W, H);
 *   quantum_vis_set_hydrogen(&qv, n, l, m);      // single orbital
 *   // or quantum_vis_set_atom(&qv, Z);           // full atom config
 *   quantum_vis_dispatch(&qv, queue, cam, frame);
 *   quantum_vis_free(&qv, dev);
 */

#ifndef QUANTUM_VOLUME_H
#define QUANTUM_VOLUME_H

#include <stdint.h>

/* Forward decl — user provides Vulkan types from their own header */
#ifdef _WIN32
  #define VK_USE_PLATFORM_WIN32_KHR
#endif
#include <vulkan/vulkan.h>

/* ─────────── Constants ─────────── */
#define QV_MAX_ORBITALS     30   /* Covers up to Zinc (Z=30) */
#define QV_DEFAULT_GRID_DIM 128  /* 128³ = 2M voxels, ~8 MB float buffer */
#define QV_DEFAULT_BOX_HALF 25.0f /* 25 a₀ ≈ 13.2 Å — fits n≤5 orbitals */
#define QV_DEFAULT_MAX_STEPS 512

/* ─────────── Orbital specification ─────────── */
typedef struct {
    int   n;          /* principal quantum number (1,2,3,...) */
    int   l;          /* angular momentum (0..n-1)           */
    int   m;          /* magnetic quantum number (-l..+l)    */
    float Z_eff;      /* effective nuclear charge (Slater)   */
    float occupation;  /* electron count (0-2)                */
    float phase_t;    /* time phase for animation            */
    float pad0, pad1; /* alignment to 32 bytes               */
} QV_OrbitalConfig;

/* ─────────── Camera for raymarcher ─────────── */
typedef struct {
    float pos[3];
    float fwd[3];
    float right[3];
    float up[3];
    float fov_y;      /* radians */
} QV_Camera;

/* ─────────── Render parameters ─────────── */
typedef struct {
    float density_mult;
    float gamma;
    float emission_scale;
    float iso_threshold;
    float bg_color[3];
    float step_size;     /* 0 = auto */
    int   max_steps;
    int   color_mode;    /* 0=physical, 1=energy, 2=phase, 3=xray */
    int   output_mode;   /* 0=|ψ|², 1=signed Re(ψ), 2=phase-encoded */
    float time;          /* animation time */
    float jitter_x;      /* DLSS: sub-pixel jitter X (0 when off) */
    float jitter_y;      /* DLSS: sub-pixel jitter Y (0 when off) */
} QV_RenderParams;

/* ─────────── Main visualization state ─────────── */
typedef struct {
    /* Vulkan handles (owned) */
    VkDevice            device;
    VkPhysicalDevice    physDevice;

    /* Grid compute (Pass 1) */
    VkPipeline          wfPipeline;
    VkPipelineLayout    wfPipeLayout;
    VkDescriptorSetLayout wfDescLayout;
    VkDescriptorPool    wfDescPool;
    VkDescriptorSet     wfDescSet;
    VkShaderModule      wfShader;

    /* Raymarch (Pass 2) */
    VkPipeline          rmPipeline;
    VkPipelineLayout    rmPipeLayout;
    VkDescriptorSetLayout rmDescLayout;
    VkDescriptorPool    rmDescPool;
    VkDescriptorSet     rmDescSet;
    VkShaderModule      rmShader;

    /* GPU buffers */
    VkBuffer            densityBuf;     /* 3D density grid (gridDim³ floats) */
    VkDeviceMemory      densityMem;
    VkBuffer            signedBuf;      /* signed ψ grid (same size) */
    VkDeviceMemory      signedMem;
    VkBuffer            orbitalBuf;     /* OrbitalConfig[QV_MAX_ORBITALS] */
    VkDeviceMemory      orbitalMem;

    /* Output images (shared with main engine or owned) */
    VkImage             outImage;
    VkImageView         outView;
    VkDeviceMemory      outMem;
    VkImage             accumImage;
    VkImageView         accumView;
    VkDeviceMemory      accumMem;
    VkImage             depthImage;      /* R32_SFLOAT depth for DLSS */
    VkImageView         depthView;
    VkDeviceMemory      depthMem;

    /* Readback (headless) */
    VkBuffer            readbackBuf;
    VkDeviceMemory      readbackMem;

    /* Command resources */
    VkCommandPool       cmdPool;
    VkCommandBuffer     cmdBuf;

    /* Configuration */
    int                gridDim;
    float              boxHalf;
    int                imageW, imageH;
    int                numOrbitals;
    QV_OrbitalConfig   orbitals[QV_MAX_ORBITALS];
    QV_RenderParams    params;
    int                needsGridUpdate; /* set to 1 when orbitals change */
} QuantumVis;

/* ─────────── API ─────────── */

/* Initialize Vulkan resources. Returns 0 on success. */
int quantum_vis_init(QuantumVis *qv,
                     VkPhysicalDevice phys, VkDevice dev,
                     uint32_t queueFamilyIdx,
                     int imageW, int imageH);

/* Configure a single hydrogen-like orbital. */
void quantum_vis_set_hydrogen(QuantumVis *qv, int n, int l, int m);

/* Configure a full atom by atomic number Z using Slater's rules. */
void quantum_vis_set_atom(QuantumVis *qv, int Z);

/* Set a custom superposition of orbitals. */
void quantum_vis_set_orbitals(QuantumVis *qv,
                              const QV_OrbitalConfig *orbs, int count);

/* Record and submit both compute passes. Blocks until complete.
 * Returns 0 on success. */
int quantum_vis_dispatch(QuantumVis *qv,
                         VkQueue queue,
                         const QV_Camera *cam,
                         int frame);

/* Read back the rendered image to CPU. Caller provides RGBA float buffer. */
int quantum_vis_readback(QuantumVis *qv, VkQueue queue,
                         float *rgba_out, int w, int h);

/* Free all Vulkan resources. */
void quantum_vis_free(QuantumVis *qv, VkDevice dev);

/* ─────────── Slater's rules helper ─────────── */
/* Compute effective nuclear charge Z_eff for orbital (n,l) in atom Z. */
float quantum_slater_z_eff(int Z, int n, int l);

/* Default render parameters. */
QV_RenderParams quantum_vis_default_params(void);

#endif /* QUANTUM_VOLUME_H */
