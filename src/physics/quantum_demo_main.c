/* quantum_demo_main.c — Standalone demo for quantum wavefunction visualization.
 *
 * Initializes Vulkan (headless or windowed via YSU_QV_WINDOW=1),
 * configures an atom/orbital, dispatches the two-pass compute pipeline,
 * and either writes output.ppm (headless) or opens an interactive window.
 *
 * Window-mode controls:
 *   Left-drag   Orbit camera (θ/φ)
 *   Scroll      Zoom in/out
 *   1-5         Switch orbital n=1..5  (hydrogen)
 *   S/P/D/F     Switch sub-shell l=0..3
 *   +/-         Change m quantum number
 *   C           Cycle color mode (physical → phase → xray)
 *   R           Reset camera to defaults
 *   ESC         Quit
 *
 * Environment variables:
 *   YSU_QV_WINDOW=1      Open interactive GLFW window
 *   YSU_QV_ATOM=Z        Visualize full atom (e.g. Z=6 for Carbon)
 *   YSU_QV_N=n           Hydrogen orbital principal quantum number
 *   YSU_QV_L=l           Angular momentum
 *   YSU_QV_M=m           Magnetic quantum number
 *   YSU_QV_GRID=128      Grid resolution (128³ default)
 *   YSU_QV_W=800         Image width
 *   YSU_QV_H=600         Image height
 *   YSU_QV_DENSITY=50    Density multiplier
 *   YSU_QV_GAMMA=0.5     Density power curve
 *   YSU_QV_COLOR=0       Color mode (0=physical, 2=phase, 3=xray)
 *   YSU_QV_MODE=0        Output mode (0=|ψ|², 1=signed, 2=phase)
 *   YSU_QV_CAM_DIST=40   Camera distance in Bohr radii
 *   YSU_QV_CAM_THETA=30  Camera elevation (degrees)
 *   YSU_QV_CAM_PHI=45    Camera azimuth (degrees)
 *
 * Build (headless only):
 *   gcc -std=c11 -O2 -o quantum_demo quantum_demo_main.c quantum_volume.c -lvulkan-1 -lm
 *
 * Build (with window mode):
 *   gcc -std=c11 -O2 -DQV_ENABLE_WINDOW -o quantum_demo quantum_demo_main.c quantum_volume.c -lvulkan-1 -lglfw3 -lgdi32 -lm
 */

#ifdef _WIN32
  #define VK_USE_PLATFORM_WIN32_KHR
#endif

/* GLFW must come before vulkan.h when using window mode */
#ifdef QV_ENABLE_WINDOW
  #define GLFW_INCLUDE_VULKAN
  #include <GLFW/glfw3.h>
#else
  #include <vulkan/vulkan.h>
#endif

#include "quantum_volume.h"
#include "nuclear_reaction.h"
#include "reactor_thermal.h"
#include "atomic_fission.h"
#include "ysu_upscale.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ─── Env helpers (same pattern as ysu_main.c) ─── */
static int env_int(const char *name, int def) {
    const char *v = getenv(name);
    return v ? atoi(v) : def;
}
static float env_float(const char *name, float def) {
    const char *v = getenv(name);
    return v ? (float)atof(v) : def;
}
static int env_bool(const char *name, int def) {
    const char *v = getenv(name);
    if (!v) return def;
    return (v[0] == '1' || v[0] == 'y' || v[0] == 'Y' || v[0] == 't' || v[0] == 'T');
}

/* ─── Minimal PPM writer (matching image.c) ─── */
static void write_ppm(const char *path, int w, int h, const float *rgba) {
    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "[QV] Cannot write %s\n", path); return; }
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    for (int i = 0; i < w * h; i++) {
        float r = rgba[i * 4 + 0];
        float g = rgba[i * 4 + 1];
        float b = rgba[i * 4 + 2];
        /* Clamp and gamma-correct for display (linear → sRGB approximate) */
        r = powf(fmaxf(fminf(r, 1.0f), 0.0f), 1.0f / 2.2f);
        g = powf(fmaxf(fminf(g, 1.0f), 0.0f), 1.0f / 2.2f);
        b = powf(fmaxf(fminf(b, 1.0f), 0.0f), 1.0f / 2.2f);
        unsigned char rgb[3] = {
            (unsigned char)(r * 255.0f + 0.5f),
            (unsigned char)(g * 255.0f + 0.5f),
            (unsigned char)(b * 255.0f + 0.5f)
        };
        fwrite(rgb, 1, 3, f);
    }
    fclose(f);
    printf("[QV] Wrote %s (%dx%d)\n", path, w, h);
}

/* ─── Vulkan instance + device setup ─── */
static VkInstance       g_instance;
static VkPhysicalDevice g_phys;
static VkDevice         g_dev;
static VkQueue          g_queue;
static uint32_t         g_qfi;
#ifdef QV_ENABLE_WINDOW
static VkSurfaceKHR    g_surface  = VK_NULL_HANDLE;
static GLFWwindow     *g_window   = NULL;
#endif

/* ── DLSS Temporal Super-Resolution state ── */
static int              g_dlss_enabled = 0;
static int              g_dlss_active  = 0;
static int              g_dlss_quality = 2;  /* YSU_UPSCALE_QUALITY_BALANCED */
static int              g_W_lo = 0, g_H_lo = 0;
static int              g_W_hi = 0, g_H_hi = 0;
static YsuUpscaleCtx    g_upscale;
static int              g_upscale_inited = 0;

/* DLSS images */
static VkImage          g_motionImage     = VK_NULL_HANDLE;
static VkImageView      g_motionView      = VK_NULL_HANDLE;
static VkDeviceMemory   g_motionMem       = VK_NULL_HANDLE;
static VkImage          g_dlssOutImage    = VK_NULL_HANDLE;
static VkImageView      g_dlssOutView     = VK_NULL_HANDLE;
static VkDeviceMemory   g_dlssOutMem      = VK_NULL_HANDLE;

/* Motion vector generation pipeline */
static VkPipeline       g_mvPipeline      = VK_NULL_HANDLE;
static VkPipelineLayout g_mvPipeLayout    = VK_NULL_HANDLE;
static VkDescriptorSetLayout g_mvDescLayout = VK_NULL_HANDLE;
static VkDescriptorPool g_mvDescPool      = VK_NULL_HANDLE;
static VkDescriptorSet  g_mvDescSet       = VK_NULL_HANDLE;
static VkShaderModule   g_mvShader        = VK_NULL_HANDLE;

/* Previous camera for motion vector generation */
static QV_Camera        g_prevCam;
static int              g_hasPrevCam = 0;
static uint32_t         g_dlssFrame  = 0;

/* ── GPU Bilateral Denoise state ── */
static int              g_denoise_enabled = 1;  /* on by default */
static VkShaderModule   g_dnShader    = VK_NULL_HANDLE;
static VkPipeline       g_dnPipeline  = VK_NULL_HANDLE;
static VkPipelineLayout g_dnPipeLayout = VK_NULL_HANDLE;
static VkDescriptorSetLayout g_dnDescLayout = VK_NULL_HANDLE;
static VkDescriptorPool g_dnDescPool  = VK_NULL_HANDLE;
static VkDescriptorSet  g_dnDescH     = VK_NULL_HANDLE;  /* H-pass: outImg→temp */
static VkDescriptorSet  g_dnDescV     = VK_NULL_HANDLE;  /* V-pass: temp→outImg */
static VkImage          g_dnTempImage = VK_NULL_HANDLE;
static VkImageView      g_dnTempView  = VK_NULL_HANDLE;
static VkDeviceMemory   g_dnTempMem   = VK_NULL_HANDLE;
static int              g_dnInited    = 0;
static int              g_dn_radius   = 3;     /* filter radius (1-16) */
static float            g_dn_sigma_s  = 2.5f;  /* spatial sigma */
static float            g_dn_sigma_r  = 0.25f; /* range sigma — wider to smooth voxel edges */

typedef struct {
    int W, H, pass, radius;
    float sigma_s, sigma_r;
    int pad0, pad1;
} DenoisePushConst;

static int init_vulkan(int windowed) {
    VkApplicationInfo app = {VK_STRUCTURE_TYPE_APPLICATION_INFO};
    app.pApplicationName = "YSU Quantum Vis";
    app.apiVersion       = VK_API_VERSION_1_2;

    VkInstanceCreateInfo ici = {VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    ici.pApplicationInfo = &app;

#ifdef QV_ENABLE_WINDOW
    /* When windowed, pull GLFW-required instance extensions (VK_KHR_surface + platform) */
    uint32_t glfw_ext_count = 0;
    const char **glfw_exts = NULL;
    if (windowed) {
        if (!glfwInit()) {
            fprintf(stderr, "[QV] glfwInit failed\n");
            return -10;
        }
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        glfwWindowHint(GLFW_RESIZABLE,  GLFW_FALSE);
        glfw_exts = glfwGetRequiredInstanceExtensions(&glfw_ext_count);
        ici.enabledExtensionCount   = glfw_ext_count;
        ici.ppEnabledExtensionNames = glfw_exts;
    }
#else
    (void)windowed;
#endif

    if (vkCreateInstance(&ici, NULL, &g_instance) != VK_SUCCESS) {
        fprintf(stderr, "[QV] vkCreateInstance failed\n");
        return -1;
    }

    uint32_t n = 0;
    vkEnumeratePhysicalDevices(g_instance, &n, NULL);
    if (n == 0) { fprintf(stderr, "[QV] No Vulkan devices\n"); return -2; }
    VkPhysicalDevice devs[8];
    vkEnumeratePhysicalDevices(g_instance, &n, devs);
    g_phys = devs[0];

    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(g_phys, &props);
    printf("[QV] GPU: %s\n", props.deviceName);

    /* Find compute+graphics queue family (for blit support) */
    uint32_t qfCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(g_phys, &qfCount, NULL);
    VkQueueFamilyProperties qfProps[16];
    vkGetPhysicalDeviceQueueFamilyProperties(g_phys, &qfCount, qfProps);
    g_qfi = UINT32_MAX;
    for (uint32_t i = 0; i < qfCount; i++) {
        if ((qfProps[i].queueFlags & VK_QUEUE_COMPUTE_BIT) &&
            (qfProps[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)) {
            g_qfi = i;
            break;
        }
    }
    /* Fallback: compute-only */
    if (g_qfi == UINT32_MAX) {
        for (uint32_t i = 0; i < qfCount; i++) {
            if (qfProps[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
                g_qfi = i;
                break;
            }
        }
    }
    if (g_qfi == UINT32_MAX) { fprintf(stderr, "[QV] No compute queue\n"); return -3; }

    float priority = 1.0f;
    VkDeviceQueueCreateInfo dqci = {VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
    dqci.queueFamilyIndex = g_qfi;
    dqci.queueCount       = 1;
    dqci.pQueuePriorities = &priority;

    VkDeviceCreateInfo dci = {VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO};
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos    = &dqci;

#ifdef QV_ENABLE_WINDOW
    /* Enable swapchain extension when windowed */
    const char *dev_exts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };
    if (windowed) {
        dci.enabledExtensionCount   = 1;
        dci.ppEnabledExtensionNames = dev_exts;
    }
#endif

    if (vkCreateDevice(g_phys, &dci, NULL, &g_dev) != VK_SUCCESS) {
        fprintf(stderr, "[QV] vkCreateDevice failed\n");
        return -4;
    }
    vkGetDeviceQueue(g_dev, g_qfi, 0, &g_queue);
    return 0;
}

static void cleanup_vulkan(void) {
#ifdef QV_ENABLE_WINDOW
    if (g_surface)  vkDestroySurfaceKHR(g_instance, g_surface, NULL);
    if (g_window)   { glfwDestroyWindow(g_window); glfwTerminate(); }
#endif
    if (g_dev)      vkDestroyDevice(g_dev, NULL);
    if (g_instance) vkDestroyInstance(g_instance, NULL);
}

/* ─── Orbital name helper ─── */
static const char *orbital_letter(int l) {
    static const char *names[] = {"s", "p", "d", "f", "g"};
    return l < 5 ? names[l] : "?";
}

/* Element names for Z = 1..36 (first 4 rows of periodic table) */
static const char *element_name(int Z) {
    static const char *names[] = {
        "?",
        "H",  "He",                                             /*  1- 2 */
        "Li", "Be", "B",  "C",  "N",  "O",  "F",  "Ne",       /*  3-10 */
        "Na", "Mg", "Al", "Si", "P",  "S",  "Cl", "Ar",       /* 11-18 */
        "K",  "Ca", "Sc", "Ti", "V",  "Cr", "Mn", "Fe",       /* 19-26 */
        "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se",       /* 27-34 */
        "Br", "Kr"                                               /* 35-36 */
    };
    if (Z < 1 || Z > 36) return "?";
    return names[Z];
}

/* Electron configuration string (e.g. "1s² 2s² 2p²") */
static const char *electron_config(int Z) {
    static char buf[128];
    static const struct { int n, l, max_e; } aufbau[] = {
        {1,0,2}, {2,0,2}, {2,1,6}, {3,0,2}, {3,1,6},
        {4,0,2}, {3,2,10},{4,1,6}, {5,0,2}, {4,2,10},
        {5,1,6}
    };
    int n_sub = (int)(sizeof(aufbau)/sizeof(aufbau[0]));
    buf[0] = '\0';
    int remaining = Z;
    for (int i = 0; i < n_sub && remaining > 0; i++) {
        int e = remaining < aufbau[i].max_e ? remaining : aufbau[i].max_e;
        remaining -= e;
        char tmp[16];
        snprintf(tmp, sizeof(tmp), "%d%s%d ", aufbau[i].n, orbital_letter(aufbau[i].l), e);
        strcat(buf, tmp);
    }
    /* trim trailing space */
    int len = (int)strlen(buf);
    if (len > 0 && buf[len-1] == ' ') buf[len-1] = '\0';
    return buf;
}

/* ─── Spherical camera helper ─── */
static void build_camera(QV_Camera *cam, float dist, float theta, float phi) {
    cam->pos[0] = dist * sinf(theta) * cosf(phi);
    cam->pos[1] = dist * cosf(theta);
    cam->pos[2] = dist * sinf(theta) * sinf(phi);

    float len = sqrtf(cam->pos[0]*cam->pos[0] + cam->pos[1]*cam->pos[1] + cam->pos[2]*cam->pos[2]);
    if (len < 1e-6f) len = 1.0f;
    cam->fwd[0] = -cam->pos[0] / len;
    cam->fwd[1] = -cam->pos[1] / len;
    cam->fwd[2] = -cam->pos[2] / len;

    float world_up[3] = {0.0f, 1.0f, 0.0f};
    cam->right[0] = cam->fwd[1] * world_up[2] - cam->fwd[2] * world_up[1];
    cam->right[1] = cam->fwd[2] * world_up[0] - cam->fwd[0] * world_up[2];
    cam->right[2] = cam->fwd[0] * world_up[1] - cam->fwd[1] * world_up[0];
    float rlen = sqrtf(cam->right[0]*cam->right[0] + cam->right[1]*cam->right[1] + cam->right[2]*cam->right[2]);
    if (rlen > 1e-6f) { cam->right[0] /= rlen; cam->right[1] /= rlen; cam->right[2] /= rlen; }

    cam->up[0] = cam->right[1] * cam->fwd[2] - cam->right[2] * cam->fwd[1];
    cam->up[1] = cam->right[2] * cam->fwd[0] - cam->right[0] * cam->fwd[2];
    cam->up[2] = cam->right[0] * cam->fwd[1] - cam->right[1] * cam->fwd[0];

    cam->fov_y = 0.8f; /* ~46° */
}

/* ═══════════════════════════════════════════════════════════════════════
 *  GLFW window mode — swapchain, sync, blit, input loop
 * ═══════════════════════════════════════════════════════════════════════ */
#ifdef QV_ENABLE_WINDOW

/* ─── GLFW mouse/scroll callback state ─── */
static double g_last_mx, g_last_my;
static int    g_dragging     = 0;
static float  g_scroll_accum = 0.0f;
static int    g_mouse_init   = 0;

static void scroll_cb(GLFWwindow *w, double xoff, double yoff) {
    (void)w; (void)xoff;
    g_scroll_accum += (float)yoff;
}

/* ─── Swapchain helpers ─── */
typedef struct {
    VkSwapchainKHR   swapchain;
    VkImage         *images;
    VkImageView     *views;
    uint32_t         count;
    VkExtent2D       extent;
    VkFormat         format;
} SwapchainInfo;

static int create_swapchain(int W, int H, SwapchainInfo *sw) {
    VkSurfaceCapabilitiesKHR caps;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(g_phys, g_surface, &caps);

    /* Pick format: B8G8R8A8_UNORM preferred (matching gpu_vulkan_demo.c) */
    uint32_t fmtCount = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(g_phys, g_surface, &fmtCount, NULL);
    VkSurfaceFormatKHR fmts[16];
    vkGetPhysicalDeviceSurfaceFormatsKHR(g_phys, g_surface, &fmtCount, fmts);
    sw->format = fmts[0].format;
    VkColorSpaceKHR cs = fmts[0].colorSpace;
    for (uint32_t i = 0; i < fmtCount; i++) {
        if (fmts[i].format == VK_FORMAT_B8G8R8A8_UNORM) {
            sw->format = fmts[i].format;
            cs = fmts[i].colorSpace;
            break;
        }
    }

    /* Pick present mode: MAILBOX > FIFO */
    uint32_t pmCount = 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(g_phys, g_surface, &pmCount, NULL);
    VkPresentModeKHR pms[8];
    vkGetPhysicalDeviceSurfacePresentModesKHR(g_phys, g_surface, &pmCount, pms);
    VkPresentModeKHR mode = VK_PRESENT_MODE_FIFO_KHR;
    for (uint32_t i = 0; i < pmCount; i++) {
        if (pms[i] == VK_PRESENT_MODE_MAILBOX_KHR) { mode = VK_PRESENT_MODE_MAILBOX_KHR; break; }
    }

    sw->extent.width  = (uint32_t)W;
    sw->extent.height = (uint32_t)H;
    if (caps.currentExtent.width != UINT32_MAX) sw->extent = caps.currentExtent;

    uint32_t imgCount = caps.minImageCount + 1;
    if (caps.maxImageCount > 0 && imgCount > caps.maxImageCount)
        imgCount = caps.maxImageCount;

    VkSwapchainCreateInfoKHR sci = {VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR};
    sci.surface          = g_surface;
    sci.minImageCount    = imgCount;
    sci.imageFormat      = sw->format;
    sci.imageColorSpace  = cs;
    sci.imageExtent      = sw->extent;
    sci.imageArrayLayers = 1;
    sci.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    sci.preTransform     = caps.currentTransform;
    sci.compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    sci.presentMode      = mode;
    sci.clipped          = VK_TRUE;

    if (vkCreateSwapchainKHR(g_dev, &sci, NULL, &sw->swapchain) != VK_SUCCESS) {
        fprintf(stderr, "[QV] vkCreateSwapchainKHR failed\n");
        return -1;
    }

    vkGetSwapchainImagesKHR(g_dev, sw->swapchain, &sw->count, NULL);
    sw->images = (VkImage *)malloc(sw->count * sizeof(VkImage));
    vkGetSwapchainImagesKHR(g_dev, sw->swapchain, &sw->count, sw->images);

    sw->views = (VkImageView *)malloc(sw->count * sizeof(VkImageView));
    for (uint32_t i = 0; i < sw->count; i++) {
        VkImageViewCreateInfo vci = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
        vci.image    = sw->images[i];
        vci.viewType = VK_IMAGE_VIEW_TYPE_2D;
        vci.format   = sw->format;
        vci.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        vci.subresourceRange.levelCount = 1;
        vci.subresourceRange.layerCount = 1;
        vkCreateImageView(g_dev, &vci, NULL, &sw->views[i]);
    }

    printf("[QV] Swapchain: %u images, %ux%u, mode=%s\n",
           sw->count, sw->extent.width, sw->extent.height,
           mode == VK_PRESENT_MODE_MAILBOX_KHR ? "MAILBOX" : "FIFO");
    return 0;
}

static void destroy_swapchain(SwapchainInfo *sw) {
    for (uint32_t i = 0; i < sw->count; i++)
        vkDestroyImageView(g_dev, sw->views[i], NULL);
    vkDestroySwapchainKHR(g_dev, sw->swapchain, NULL);
    free(sw->images);
    free(sw->views);
    memset(sw, 0, sizeof(*sw));
}

/* ═══════════════════════════════════════════════════════════════════════
 *  DLSS Temporal Super-Resolution — helpers
 * ═══════════════════════════════════════════════════════════════════════ */

/* Read a SPIR-V file into a malloc'd buffer. Caller frees. */
static uint32_t *dlss_load_spv(const char *path, size_t *out_size) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "[DLSS] Cannot open shader: %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint32_t *code = (uint32_t *)malloc((size_t)sz);
    if (!code) { fclose(f); return NULL; }
    fread(code, 1, (size_t)sz, f);
    fclose(f);
    *out_size = (size_t)sz;
    return code;
}

/* Create a 2D image + view (reuses pattern from quantum_volume.c) */
static int dlss_create_image(int W, int H, VkFormat fmt, VkImageUsageFlags usage,
                             VkImage *img, VkImageView *view, VkDeviceMemory *mem) {
    VkImageCreateInfo ci = {VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    ci.imageType   = VK_IMAGE_TYPE_2D;
    ci.format      = fmt;
    ci.extent      = (VkExtent3D){(uint32_t)W, (uint32_t)H, 1};
    ci.mipLevels   = 1;
    ci.arrayLayers = 1;
    ci.samples     = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling      = VK_IMAGE_TILING_OPTIMAL;
    ci.usage       = usage;
    if (vkCreateImage(g_dev, &ci, NULL, img) != VK_SUCCESS) return -1;

    VkMemoryRequirements req;
    vkGetImageMemoryRequirements(g_dev, *img, &req);

    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(g_phys, &mp);
    uint32_t mi = UINT32_MAX;
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
        if ((req.memoryTypeBits & (1u << i)) &&
            (mp.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
            { mi = i; break; }
    }
    if (mi == UINT32_MAX) return -2;

    VkMemoryAllocateInfo ai = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    ai.allocationSize  = req.size;
    ai.memoryTypeIndex = mi;
    if (vkAllocateMemory(g_dev, &ai, NULL, mem) != VK_SUCCESS) return -3;
    vkBindImageMemory(g_dev, *img, *mem, 0);

    VkImageViewCreateInfo vi = {VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
    vi.image    = *img;
    vi.viewType = VK_IMAGE_VIEW_TYPE_2D;
    vi.format   = fmt;
    vi.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    vi.subresourceRange.levelCount = 1;
    vi.subresourceRange.layerCount = 1;
    if (vkCreateImageView(g_dev, &vi, NULL, view) != VK_SUCCESS) return -4;
    return 0;
}

/* Initialize motion vector generation pipeline */
static int dlss_init_motion_gen(int W_lo, int H_lo) {
    /* Descriptor layout: 0=depth(storage read), 1=motion(storage write) */
    VkDescriptorSetLayoutBinding bindings[2] = {
        {0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
    };
    VkDescriptorSetLayoutCreateInfo dslci = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    dslci.bindingCount = 2;
    dslci.pBindings    = bindings;
    if (vkCreateDescriptorSetLayout(g_dev, &dslci, NULL, &g_mvDescLayout) != VK_SUCCESS) return -1;

    /* Push constants: MotionGenPC = 128 bytes */
    VkPushConstantRange pcr = {VK_SHADER_STAGE_COMPUTE_BIT, 0, 128};
    VkPipelineLayoutCreateInfo plci = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    plci.setLayoutCount         = 1;
    plci.pSetLayouts            = &g_mvDescLayout;
    plci.pushConstantRangeCount = 1;
    plci.pPushConstantRanges    = &pcr;
    if (vkCreatePipelineLayout(g_dev, &plci, NULL, &g_mvPipeLayout) != VK_SUCCESS) return -2;

    /* Load shader */
    g_mvShader = VK_NULL_HANDLE;
    {
        FILE *f = fopen("shaders/qv_motion_gen.comp.spv", "rb");
        if (!f) { fprintf(stderr, "[DLSS] Cannot open motion gen shader SPV\n"); return -3; }
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        fseek(f, 0, SEEK_SET);
        uint32_t *code = (uint32_t *)malloc((size_t)sz);
        fread(code, 1, (size_t)sz, f);
        fclose(f);
        VkShaderModuleCreateInfo smci = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
        smci.codeSize = (size_t)sz;
        smci.pCode    = code;
        vkCreateShaderModule(g_dev, &smci, NULL, &g_mvShader);
        free(code);
    }
    if (g_mvShader == VK_NULL_HANDLE) return -3;

    /* Compute pipeline */
    VkComputePipelineCreateInfo cpci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
    cpci.stage.sType  = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    cpci.stage.stage  = VK_SHADER_STAGE_COMPUTE_BIT;
    cpci.stage.module = g_mvShader;
    cpci.stage.pName  = "main";
    cpci.layout       = g_mvPipeLayout;
    if (vkCreateComputePipelines(g_dev, VK_NULL_HANDLE, 1, &cpci, NULL, &g_mvPipeline) != VK_SUCCESS)
        return -4;

    /* Descriptor pool + set */
    VkDescriptorPoolSize ps = {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 2};
    VkDescriptorPoolCreateInfo dpci = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    dpci.maxSets       = 1;
    dpci.poolSizeCount = 1;
    dpci.pPoolSizes    = &ps;
    if (vkCreateDescriptorPool(g_dev, &dpci, NULL, &g_mvDescPool) != VK_SUCCESS) return -5;

    VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    dsai.descriptorPool     = g_mvDescPool;
    dsai.descriptorSetCount = 1;
    dsai.pSetLayouts        = &g_mvDescLayout;
    if (vkAllocateDescriptorSets(g_dev, &dsai, &g_mvDescSet) != VK_SUCCESS) return -6;

    return 0;
}

/* Update motion gen descriptor set with current image views */
static void dlss_update_motion_desc(VkImageView depthView, VkImageView motionView) {
    VkDescriptorImageInfo depInfo  = {VK_NULL_HANDLE, depthView,  VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorImageInfo mvInfo   = {VK_NULL_HANDLE, motionView, VK_IMAGE_LAYOUT_GENERAL};
    VkWriteDescriptorSet writes[2] = {
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, g_mvDescSet, 0, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &depInfo, NULL, NULL},
        {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, NULL, g_mvDescSet, 1, 0, 1,
         VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, &mvInfo, NULL, NULL},
    };
    vkUpdateDescriptorSets(g_dev, 2, writes, 0, NULL);
}

/* Motion gen push constant struct (must match qv_motion_gen.comp) */
typedef struct {
    int   W, H;
    float _pad0, _pad1;
    float camPosX, camPosY, camPosZ;
    float camFwdX, camFwdY, camFwdZ;
    float camRightX, camRightY, camRightZ;
    float camUpX, camUpY, camUpZ;
    float fov;
    float prevPosX, prevPosY, prevPosZ;
    float prevFwdX, prevFwdY, prevFwdZ;
    float prevRightX, prevRightY, prevRightZ;
    float prevUpX, prevUpY, prevUpZ;
    float prevFov;
} MotionGenPC;

/* Initialize the full DLSS system */
/* ── GPU Bilateral Denoise initialization ── */
static int denoise_init(QuantumVis *qv) {
    int W = qv->imageW, H = qv->imageH;

    /* Create temp ping-pong image (same format as outImage: rgba32f) */
    int rc = dlss_create_image(W, H, VK_FORMAT_R32G32B32A32_SFLOAT,
            VK_IMAGE_USAGE_STORAGE_BIT,
            &g_dnTempImage, &g_dnTempView, &g_dnTempMem);
    if (rc) { fprintf(stderr, "[DENOISE] temp image failed: %d\n", rc); return rc; }

    /* Transition temp image UNDEFINED → GENERAL */
    {
        VkCommandBuffer icb;
        VkCommandBufferAllocateInfo ica = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
        ica.commandPool = qv->cmdPool;
        ica.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ica.commandBufferCount = 1;
        vkAllocateCommandBuffers(g_dev, &ica, &icb);
        VkCommandBufferBeginInfo icbi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        icbi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        vkBeginCommandBuffer(icb, &icbi);
        VkImageMemoryBarrier ib = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
        ib.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        ib.newLayout = VK_IMAGE_LAYOUT_GENERAL;
        ib.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        ib.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        ib.srcAccessMask = 0;
        ib.dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
        ib.image = g_dnTempImage;
        ib.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        ib.subresourceRange.levelCount = 1;
        ib.subresourceRange.layerCount = 1;
        vkCmdPipelineBarrier(icb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, NULL, 0, NULL, 1, &ib);
        vkEndCommandBuffer(icb);
        VkSubmitInfo isi = {VK_STRUCTURE_TYPE_SUBMIT_INFO};
        isi.commandBufferCount = 1;
        isi.pCommandBuffers = &icb;
        vkQueueSubmit(g_queue, 1, &isi, VK_NULL_HANDLE);
        vkQueueWaitIdle(g_queue);
        vkFreeCommandBuffers(g_dev, qv->cmdPool, 1, &icb);
    }

    /* Load denoise.comp.spv */
    size_t spv_sz = 0;
    uint32_t *spv = dlss_load_spv("shaders/denoise.comp.spv", &spv_sz);
    if (!spv) { fprintf(stderr, "[DENOISE] Cannot load denoise.comp.spv\n"); return -5; }
    VkShaderModuleCreateInfo smci = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
    smci.codeSize = spv_sz;
    smci.pCode = spv;
    vkCreateShaderModule(g_dev, &smci, NULL, &g_dnShader);
    free(spv);

    /* Descriptor set layout: binding 0 = inImg, binding 1 = outImg */
    VkDescriptorSetLayoutBinding binds[2] = {
        {0, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
        {1, VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL},
    };
    VkDescriptorSetLayoutCreateInfo dslci = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
    dslci.bindingCount = 2;
    dslci.pBindings = binds;
    vkCreateDescriptorSetLayout(g_dev, &dslci, NULL, &g_dnDescLayout);

    /* Push constants: DenoisePushConst = 32 bytes */
    VkPushConstantRange pcr = {VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(DenoisePushConst)};
    VkPipelineLayoutCreateInfo plci = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    plci.setLayoutCount = 1;
    plci.pSetLayouts = &g_dnDescLayout;
    plci.pushConstantRangeCount = 1;
    plci.pPushConstantRanges = &pcr;
    vkCreatePipelineLayout(g_dev, &plci, NULL, &g_dnPipeLayout);

    /* Compute pipeline */
    VkPipelineShaderStageCreateInfo ssci = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO};
    ssci.stage = VK_SHADER_STAGE_COMPUTE_BIT;
    ssci.module = g_dnShader;
    ssci.pName = "main";
    VkComputePipelineCreateInfo cpci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
    cpci.stage = ssci;
    cpci.layout = g_dnPipeLayout;
    vkCreateComputePipelines(g_dev, VK_NULL_HANDLE, 1, &cpci, NULL, &g_dnPipeline);

    /* Descriptor pool (2 sets × 2 bindings = 4 storage images) */
    VkDescriptorPoolSize ps = {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 4};
    VkDescriptorPoolCreateInfo dpci = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    dpci.maxSets = 2;
    dpci.poolSizeCount = 1;
    dpci.pPoolSizes = &ps;
    vkCreateDescriptorPool(g_dev, &dpci, NULL, &g_dnDescPool);

    /* Allocate 2 descriptor sets */
    VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    dsai.descriptorPool = g_dnDescPool;
    dsai.descriptorSetCount = 1;
    dsai.pSetLayouts = &g_dnDescLayout;
    vkAllocateDescriptorSets(g_dev, &dsai, &g_dnDescH);
    vkAllocateDescriptorSets(g_dev, &dsai, &g_dnDescV);

    /* H-pass: in=outImage, out=temp */
    VkDescriptorImageInfo di_h_in  = {VK_NULL_HANDLE, qv->outView, VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorImageInfo di_h_out = {VK_NULL_HANDLE, g_dnTempView, VK_IMAGE_LAYOUT_GENERAL};
    VkWriteDescriptorSet wh[2];
    memset(wh, 0, sizeof(wh));
    wh[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    wh[0].dstSet = g_dnDescH; wh[0].dstBinding = 0;
    wh[0].descriptorCount = 1; wh[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    wh[0].pImageInfo = &di_h_in;
    wh[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    wh[1].dstSet = g_dnDescH; wh[1].dstBinding = 1;
    wh[1].descriptorCount = 1; wh[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    wh[1].pImageInfo = &di_h_out;
    vkUpdateDescriptorSets(g_dev, 2, wh, 0, NULL);

    /* V-pass: in=temp, out=outImage */
    VkDescriptorImageInfo di_v_in  = {VK_NULL_HANDLE, g_dnTempView, VK_IMAGE_LAYOUT_GENERAL};
    VkDescriptorImageInfo di_v_out = {VK_NULL_HANDLE, qv->outView, VK_IMAGE_LAYOUT_GENERAL};
    VkWriteDescriptorSet wv[2];
    memset(wv, 0, sizeof(wv));
    wv[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    wv[0].dstSet = g_dnDescV; wv[0].dstBinding = 0;
    wv[0].descriptorCount = 1; wv[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    wv[0].pImageInfo = &di_v_in;
    wv[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    wv[1].dstSet = g_dnDescV; wv[1].dstBinding = 1;
    wv[1].descriptorCount = 1; wv[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    wv[1].pImageInfo = &di_v_out;
    vkUpdateDescriptorSets(g_dev, 2, wv, 0, NULL);

    g_dnInited = 1;
    printf("[DENOISE] GPU bilateral filter initialized: radius=%d sigma_s=%.1f sigma_r=%.2f\n",
           g_dn_radius, g_dn_sigma_s, g_dn_sigma_r);
    printf("[DENOISE]   Toggle: B key | runs on %dx%d image\n", W, H);
    return 0;
}

/* Record 2-pass bilateral denoise into an existing command buffer */
static void denoise_cmd_record(VkCommandBuffer cb, int W, int H) {
    if (!g_dnInited) return;

    /* Barrier: raymarch write → denoise read */
    VkMemoryBarrier mb = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
    mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, NULL, 0, NULL);

    vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, g_dnPipeline);

    DenoisePushConst pc;
    pc.W = W; pc.H = H;
    pc.radius = g_dn_radius;
    pc.sigma_s = g_dn_sigma_s;
    pc.sigma_r = g_dn_sigma_r;
    pc.pad0 = 0; pc.pad1 = 0;

    uint32_t gx = ((uint32_t)W + 15) / 16;
    uint32_t gy = ((uint32_t)H + 15) / 16;

    /* Pass 0: Horizontal — outImage → temp */
    pc.pass = 0;
    vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE,
        g_dnPipeLayout, 0, 1, &g_dnDescH, 0, NULL);
    vkCmdPushConstants(cb, g_dnPipeLayout, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
    vkCmdDispatch(cb, gx, gy, 1);

    /* Barrier between H and V passes */
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, NULL, 0, NULL);

    /* Pass 1: Vertical — temp → outImage */
    pc.pass = 1;
    vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE,
        g_dnPipeLayout, 0, 1, &g_dnDescV, 0, NULL);
    vkCmdPushConstants(cb, g_dnPipeLayout, VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), &pc);
    vkCmdDispatch(cb, gx, gy, 1);

    /* Barrier: denoise write → next stage read */
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 1, &mb, 0, NULL, 0, NULL);
}

static void denoise_cleanup(void) {
    if (g_dnPipeline)    vkDestroyPipeline(g_dev, g_dnPipeline, NULL);
    if (g_dnPipeLayout)  vkDestroyPipelineLayout(g_dev, g_dnPipeLayout, NULL);
    if (g_dnDescPool)    vkDestroyDescriptorPool(g_dev, g_dnDescPool, NULL);
    if (g_dnDescLayout)  vkDestroyDescriptorSetLayout(g_dev, g_dnDescLayout, NULL);
    if (g_dnShader)      vkDestroyShaderModule(g_dev, g_dnShader, NULL);
    if (g_dnTempView)    vkDestroyImageView(g_dev, g_dnTempView, NULL);
    if (g_dnTempImage)   { vkDestroyImage(g_dev, g_dnTempImage, NULL); vkFreeMemory(g_dev, g_dnTempMem, NULL); }
    g_dnPipeline = VK_NULL_HANDLE;
    g_dnTempImage = VK_NULL_HANDLE;
    g_dnInited = 0;
}

static int dlss_init_system(QuantumVis *qv) {
    int rc;

    /* Create motion vector image (low-res, R16G16_SFLOAT) */
    rc = dlss_create_image(g_W_lo, g_H_lo, VK_FORMAT_R16G16_SFLOAT,
            VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            &g_motionImage, &g_motionView, &g_motionMem);
    if (rc) { fprintf(stderr, "[DLSS] motion image failed: %d\n", rc); return rc; }

    /* Create DLSS output image (display-res, R16G16B16A16_SFLOAT) */
    rc = dlss_create_image(g_W_hi, g_H_hi, VK_FORMAT_R16G16B16A16_SFLOAT,
            VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            &g_dlssOutImage, &g_dlssOutView, &g_dlssOutMem);
    if (rc) { fprintf(stderr, "[DLSS] output image failed: %d\n", rc); return rc; }

    /* Init motion generation pipeline */
    rc = dlss_init_motion_gen(g_W_lo, g_H_lo);
    if (rc) { fprintf(stderr, "[DLSS] motion gen pipeline failed: %d\n", rc); return rc; }

    /* Update motion gen descriptors */
    dlss_update_motion_desc(qv->depthView, g_motionView);

    /* Load DLSS upscale shader SPVs */
    size_t reproj_sz = 0, neural_sz = 0, sharpen_sz = 0;
    uint32_t *reproj_spv  = dlss_load_spv("shaders/upscale_reproj.spv", &reproj_sz);
    uint32_t *neural_spv  = dlss_load_spv("shaders/upscale_neural.spv", &neural_sz);
    uint32_t *sharpen_spv = dlss_load_spv("shaders/upscale_sharpen.spv", &sharpen_sz);
    if (!reproj_spv || !neural_spv || !sharpen_spv) {
        fprintf(stderr, "[DLSS] Failed to load upscale shader SPVs\n");
        free(reproj_spv); free(neural_spv); free(sharpen_spv);
        return -10;
    }

    /* Init DLSS upscale context */
    YsuUpscaleInitInfo info;
    memset(&info, 0, sizeof(info));
    info.device             = g_dev;
    info.phys_device        = g_phys;
    info.queue_family_index = g_qfi;
    info.compute_queue      = g_queue;
    info.max_display_w      = (uint32_t)g_W_hi;
    info.max_display_h      = (uint32_t)g_H_hi;
    info.weight_file_path   = NULL; /* No neural weights — use temporal fallback */
    info.spv_reproj         = reproj_spv;
    info.spv_reproj_size    = reproj_sz;
    info.spv_neural         = neural_spv;
    info.spv_neural_size    = neural_sz;
    info.spv_sharpen        = sharpen_spv;
    info.spv_sharpen_size   = sharpen_sz;
    info.allocator          = NULL;

    VkResult vr = ysu_upscale_init(&g_upscale, &info);
    free(reproj_spv); free(neural_spv); free(sharpen_spv);
    if (vr != VK_SUCCESS) {
        fprintf(stderr, "[DLSS] ysu_upscale_init failed: %d\n", (int)vr);
        return -11;
    }

    g_upscale_inited = 1;

    /* If no neural weights loaded, create a tiny dummy buffer so that
     * descriptor set binding 5 (STORAGE_BUFFER for weights) is always valid.
     * Without this, the validation layer reports an unwritten descriptor. */
    if (!g_upscale.weight_buf) {
        VkBufferCreateInfo bci = {VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        bci.size  = 16;
        bci.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
        vkCreateBuffer(g_dev, &bci, NULL, &g_upscale.weight_buf);

        VkMemoryRequirements mreq;
        vkGetBufferMemoryRequirements(g_dev, g_upscale.weight_buf, &mreq);

        VkPhysicalDeviceMemoryProperties mp;
        vkGetPhysicalDeviceMemoryProperties(g_phys, &mp);
        uint32_t mti = 0;
        for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
            if ((mreq.memoryTypeBits & (1u << i)) &&
                (mp.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
                { mti = i; break; }
        }

        VkMemoryAllocateInfo mai = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
        mai.allocationSize  = mreq.size;
        mai.memoryTypeIndex = mti;
        vkAllocateMemory(g_dev, &mai, NULL, &g_upscale.weight_mem);
        vkBindBufferMemory(g_dev, g_upscale.weight_buf, g_upscale.weight_mem, 0);
    }

    /* Transition ysu_upscale internal images from UNDEFINED → GENERAL.
     * The upscale library creates history/reproj/confidence images but does
     * not transition them, so we must do it here with a one-shot command. */
    {
        VkCommandBuffer icb;
        VkCommandBufferAllocateInfo ica = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
        ica.commandPool        = qv->cmdPool;
        ica.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        ica.commandBufferCount = 1;
        vkAllocateCommandBuffers(g_dev, &ica, &icb);

        VkCommandBufferBeginInfo icbi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        icbi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        vkBeginCommandBuffer(icb, &icbi);

        /* 4 internal images + our motion + dlssOut = 6 barriers */
        VkImageMemoryBarrier ibs[6];
        memset(ibs, 0, sizeof(ibs));
        for (int i = 0; i < 6; i++) {
            ibs[i].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            ibs[i].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            ibs[i].newLayout = VK_IMAGE_LAYOUT_GENERAL;
            ibs[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            ibs[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            ibs[i].srcAccessMask = 0;
            ibs[i].dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
            ibs[i].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            ibs[i].subresourceRange.levelCount = 1;
            ibs[i].subresourceRange.layerCount = 1;
        }
        ibs[0].image = g_upscale.history_img[0];
        ibs[1].image = g_upscale.history_img[1];
        ibs[2].image = g_upscale.reproj_img;
        ibs[3].image = g_upscale.confidence_img;
        ibs[4].image = g_motionImage;
        ibs[5].image = g_dlssOutImage;

        vkCmdPipelineBarrier(icb,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 0, NULL, 0, NULL, 6, ibs);

        vkEndCommandBuffer(icb);

        VkSubmitInfo isi = {VK_STRUCTURE_TYPE_SUBMIT_INFO};
        isi.commandBufferCount = 1;
        isi.pCommandBuffers    = &icb;
        vkQueueSubmit(g_queue, 1, &isi, VK_NULL_HANDLE);
        vkQueueWaitIdle(g_queue);

        vkFreeCommandBuffers(g_dev, qv->cmdPool, 1, &icb);
    }

    printf("[DLSS] Temporal Super-Resolution initialized:\n");
    printf("[DLSS]   Internal: %dx%d → Display: %dx%d (%.1fx upscale)\n",
           g_W_lo, g_H_lo, g_W_hi, g_H_hi,
           (float)g_W_hi / (float)g_W_lo);
    printf("[DLSS]   Quality: %s  Mode: %s\n",
           (const char *[]){"Ultra Perf","Performance","Balanced","Quality","Ultra"}[g_dlss_quality],
           g_upscale.has_neural_weights ? "Neural" : "Temporal Fallback");
    printf("[DLSS]   Toggle: U key | Info: I key\n");

    return 0;
}

/* Transition an image between layouts (in a recording command buffer) */
static void dlss_cmd_transition(VkCommandBuffer cb, VkImage img,
                                VkImageLayout oldL, VkImageLayout newL,
                                VkAccessFlags srcA, VkAccessFlags dstA,
                                VkPipelineStageFlags srcS, VkPipelineStageFlags dstS) {
    VkImageMemoryBarrier b = {VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    b.oldLayout           = oldL;
    b.newLayout           = newL;
    b.srcAccessMask       = srcA;
    b.dstAccessMask       = dstA;
    b.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.image               = img;
    b.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b.subresourceRange.levelCount = 1;
    b.subresourceRange.layerCount = 1;
    vkCmdPipelineBarrier(cb, srcS, dstS, 0, 0, NULL, 0, NULL, 1, &b);
}

/* Record DLSS commands: motion gen + 3-pass upscale (into an already-recording cb) */
static void dlss_cmd_record(VkCommandBuffer cb, QuantumVis *qv,
                            const QV_Camera *cam, float dt, uint32_t frame_idx) {
    /* One-shot diagnostic */
    static int first_print = 1;
    if (first_print) {
        printf("[DLSS] First DLSS frame recorded (motion gen + 3-pass upscale)\n");
        first_print = 0;
    }
    /* ── Step 0: (images already transitioned UNDEFINED→GENERAL at init) ── */

    /* ── Step 1: Generate motion vectors ── */
    {
        /* Barrier: depth write → read */
        VkMemoryBarrier mb = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
        mb.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        mb.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
        vkCmdPipelineBarrier(cb,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 1, &mb, 0, NULL, 0, NULL);

        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, g_mvPipeline);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE,
                                g_mvPipeLayout, 0, 1, &g_mvDescSet, 0, NULL);

        /* Fill push constants */
        const QV_Camera *prev = g_hasPrevCam ? &g_prevCam : cam;
        MotionGenPC pc;
        memset(&pc, 0, sizeof(pc));
        pc.W = g_W_lo;  pc.H = g_H_lo;
        pc.camPosX = cam->pos[0]; pc.camPosY = cam->pos[1]; pc.camPosZ = cam->pos[2];
        pc.camFwdX = cam->fwd[0]; pc.camFwdY = cam->fwd[1]; pc.camFwdZ = cam->fwd[2];
        pc.camRightX = cam->right[0]; pc.camRightY = cam->right[1]; pc.camRightZ = cam->right[2];
        pc.camUpX = cam->up[0]; pc.camUpY = cam->up[1]; pc.camUpZ = cam->up[2];
        pc.fov = cam->fov_y;
        pc.prevPosX = prev->pos[0]; pc.prevPosY = prev->pos[1]; pc.prevPosZ = prev->pos[2];
        pc.prevFwdX = prev->fwd[0]; pc.prevFwdY = prev->fwd[1]; pc.prevFwdZ = prev->fwd[2];
        pc.prevRightX = prev->right[0]; pc.prevRightY = prev->right[1]; pc.prevRightZ = prev->right[2];
        pc.prevUpX = prev->up[0]; pc.prevUpY = prev->up[1]; pc.prevUpZ = prev->up[2];
        pc.prevFov = prev->fov_y;

        vkCmdPushConstants(cb, g_mvPipeLayout, VK_SHADER_STAGE_COMPUTE_BIT,
                           0, sizeof(pc), &pc);
        vkCmdDispatch(cb, ((uint32_t)g_W_lo + 15) / 16,
                          ((uint32_t)g_H_lo + 15) / 16, 1);
    }

    /* ── Step 2: Transition images for DLSS sampling ── */
    {
        /* outImage, depthImage, motionImage: GENERAL → SHADER_READ_ONLY */
        VkImageMemoryBarrier bars[3];
        memset(bars, 0, sizeof(bars));
        for (int i = 0; i < 3; i++) {
            bars[i].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            bars[i].srcAccessMask       = VK_ACCESS_SHADER_WRITE_BIT;
            bars[i].dstAccessMask       = VK_ACCESS_SHADER_READ_BIT;
            bars[i].oldLayout           = VK_IMAGE_LAYOUT_GENERAL;
            bars[i].newLayout           = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            bars[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bars[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bars[i].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            bars[i].subresourceRange.levelCount = 1;
            bars[i].subresourceRange.layerCount = 1;
        }
        bars[0].image = qv->outImage;
        bars[1].image = qv->depthImage;
        bars[2].image = g_motionImage;
        vkCmdPipelineBarrier(cb,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 0, NULL, 0, NULL, 3, bars);
    }

    /* ── Step 3: Run DLSS 3-pass upscale ── */
    {
        YsuJitter jitter = ysu_upscale_jitter(frame_idx);

        YsuUpscaleFrameParams fp;
        memset(&fp, 0, sizeof(fp));
        fp.color_lo    = qv->outView;
        fp.depth_lo    = qv->depthView;
        fp.motion_vec  = g_motionView;
        fp.output_hi   = g_dlssOutView;
        fp.w_lo        = (uint32_t)g_W_lo;
        fp.h_lo        = (uint32_t)g_H_lo;
        fp.w_hi        = (uint32_t)g_W_hi;
        fp.h_hi        = (uint32_t)g_H_hi;
        fp.jitter      = jitter;
        fp.frame_index = frame_idx;
        fp.dt          = dt;
        fp.near_plane  = 0.1f;
        fp.far_plane   = 1000.0f;
        fp.sharpness   = 0.3f;
        fp.clamp_gamma = 1.0f;
        fp.debug_mode  = 0;

        ysu_upscale_update_descriptors(&g_upscale, &fp);
        ysu_upscale_execute(&g_upscale, cb, &fp);
    }

    /* ── Step 4: Transition images back to GENERAL ── */
    {
        VkImageMemoryBarrier bars[3];
        memset(bars, 0, sizeof(bars));
        for (int i = 0; i < 3; i++) {
            bars[i].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            bars[i].srcAccessMask       = VK_ACCESS_SHADER_READ_BIT;
            bars[i].dstAccessMask       = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
            bars[i].oldLayout           = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            bars[i].newLayout           = VK_IMAGE_LAYOUT_GENERAL;
            bars[i].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bars[i].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            bars[i].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            bars[i].subresourceRange.levelCount = 1;
            bars[i].subresourceRange.layerCount = 1;
        }
        bars[0].image = qv->outImage;
        bars[1].image = qv->depthImage;
        bars[2].image = g_motionImage;
        vkCmdPipelineBarrier(cb,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
            0, 0, NULL, 0, NULL, 3, bars);
    }
}

/* Blit from source image to swapchain with potentially different src/dst sizes */
static void cmd_blit_to_swapchain_scaled(VkCommandBuffer cb,
                                         VkImage src, VkImageLayout srcLayout,
                                         int srcW, int srcH,
                                         VkImage dst, VkExtent2D dstExt,
                                         VkFilter filter) {
    /* Transition src → TRANSFER_SRC, dst → TRANSFER_DST */
    VkImageMemoryBarrier b0[2];
    memset(b0, 0, sizeof(b0));

    b0[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b0[0].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    b0[0].dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    b0[0].oldLayout     = srcLayout;
    b0[0].newLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    b0[0].image         = src;
    b0[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b0[0].subresourceRange.levelCount = 1;
    b0[0].subresourceRange.layerCount = 1;

    b0[1].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b0[1].srcAccessMask = 0;
    b0[1].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    b0[1].oldLayout     = VK_IMAGE_LAYOUT_UNDEFINED;
    b0[1].newLayout     = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    b0[1].image         = dst;
    b0[1].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b0[1].subresourceRange.levelCount = 1;
    b0[1].subresourceRange.layerCount = 1;

    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                         0, 0, NULL, 0, NULL, 2, b0);

    VkImageBlit blit;
    memset(&blit, 0, sizeof(blit));
    blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.srcSubresource.layerCount = 1;
    blit.srcOffsets[1].x = srcW;
    blit.srcOffsets[1].y = srcH;
    blit.srcOffsets[1].z = 1;
    blit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.dstSubresource.layerCount = 1;
    blit.dstOffsets[1].x = (int32_t)dstExt.width;
    blit.dstOffsets[1].y = (int32_t)dstExt.height;
    blit.dstOffsets[1].z = 1;

    vkCmdBlitImage(cb, src, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                   dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit, filter);

    /* Transition back: src → GENERAL  (needs COMPUTE stage for shader write) */
    VkImageMemoryBarrier b1_src;
    memset(&b1_src, 0, sizeof(b1_src));
    b1_src.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b1_src.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    b1_src.dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    b1_src.oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    b1_src.newLayout     = VK_IMAGE_LAYOUT_GENERAL;
    b1_src.image         = src;
    b1_src.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b1_src.subresourceRange.levelCount = 1;
    b1_src.subresourceRange.layerCount = 1;
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                         0, 0, NULL, 0, NULL, 1, &b1_src);

    /* Transition dst → PRESENT_SRC  (no shader access needed) */
    VkImageMemoryBarrier b1_dst;
    memset(&b1_dst, 0, sizeof(b1_dst));
    b1_dst.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b1_dst.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    b1_dst.dstAccessMask = 0;
    b1_dst.oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    b1_dst.newLayout     = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    b1_dst.image         = dst;
    b1_dst.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b1_dst.subresourceRange.levelCount = 1;
    b1_dst.subresourceRange.layerCount = 1;
    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                         0, 0, NULL, 0, NULL, 1, &b1_dst);
}

/* Cleanup all DLSS resources */
static void dlss_cleanup(void) {
    if (g_upscale_inited) {
        ysu_upscale_destroy(&g_upscale);
        g_upscale_inited = 0;
    }
    if (g_mvPipeline)    vkDestroyPipeline(g_dev, g_mvPipeline, NULL);
    if (g_mvPipeLayout)  vkDestroyPipelineLayout(g_dev, g_mvPipeLayout, NULL);
    if (g_mvDescPool)    vkDestroyDescriptorPool(g_dev, g_mvDescPool, NULL);
    if (g_mvDescLayout)  vkDestroyDescriptorSetLayout(g_dev, g_mvDescLayout, NULL);
    if (g_mvShader)      vkDestroyShaderModule(g_dev, g_mvShader, NULL);
    if (g_motionView)    vkDestroyImageView(g_dev, g_motionView, NULL);
    if (g_motionImage)   { vkDestroyImage(g_dev, g_motionImage, NULL); vkFreeMemory(g_dev, g_motionMem, NULL); }
    if (g_dlssOutView)   vkDestroyImageView(g_dev, g_dlssOutView, NULL);
    if (g_dlssOutImage)  { vkDestroyImage(g_dev, g_dlssOutImage, NULL); vkFreeMemory(g_dev, g_dlssOutMem, NULL); }
    g_mvPipeline = VK_NULL_HANDLE;
    g_mvPipeLayout = VK_NULL_HANDLE;
    g_motionImage = VK_NULL_HANDLE;
    g_dlssOutImage = VK_NULL_HANDLE;
}

/* ─── Blit compute output → swapchain image (within existing command buffer) ─── */
static void cmd_blit_to_swapchain(VkCommandBuffer cb, VkImage src, VkImage dst, VkExtent2D ext) {
    /* Transition src: GENERAL → TRANSFER_SRC, dst: PRESENT_SRC → TRANSFER_DST */
    VkImageMemoryBarrier b0[2];
    memset(b0, 0, sizeof(b0));

    b0[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b0[0].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    b0[0].dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    b0[0].oldLayout     = VK_IMAGE_LAYOUT_GENERAL;
    b0[0].newLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    b0[0].image         = src;
    b0[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b0[0].subresourceRange.levelCount = 1;
    b0[0].subresourceRange.layerCount = 1;

    b0[1].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b0[1].srcAccessMask = 0;
    b0[1].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    b0[1].oldLayout     = VK_IMAGE_LAYOUT_UNDEFINED;
    b0[1].newLayout     = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    b0[1].image         = dst;
    b0[1].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b0[1].subresourceRange.levelCount = 1;
    b0[1].subresourceRange.layerCount = 1;

    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                         0, 0, NULL, 0, NULL, 2, b0);

    /* Blit (handles format conversion R16G16B16A16_SFLOAT → B8G8R8A8_UNORM) */
    VkImageBlit blit;
    memset(&blit, 0, sizeof(blit));
    blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.srcSubresource.layerCount = 1;
    blit.srcOffsets[1].x = (int32_t)ext.width;
    blit.srcOffsets[1].y = (int32_t)ext.height;
    blit.srcOffsets[1].z = 1;
    blit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.dstSubresource.layerCount = 1;
    blit.dstOffsets[1].x = (int32_t)ext.width;
    blit.dstOffsets[1].y = (int32_t)ext.height;
    blit.dstOffsets[1].z = 1;

    vkCmdBlitImage(cb, src, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                   dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &blit, VK_FILTER_NEAREST);

    /* Transition back: src → GENERAL, dst → PRESENT_SRC */
    VkImageMemoryBarrier b1[2];
    memset(b1, 0, sizeof(b1));

    b1[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b1[0].srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    b1[0].dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    b1[0].oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    b1[0].newLayout     = VK_IMAGE_LAYOUT_GENERAL;
    b1[0].image         = src;
    b1[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b1[0].subresourceRange.levelCount = 1;
    b1[0].subresourceRange.layerCount = 1;

    b1[1].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    b1[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    b1[1].dstAccessMask = 0;
    b1[1].oldLayout     = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    b1[1].newLayout     = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    b1[1].image         = dst;
    b1[1].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    b1[1].subresourceRange.levelCount = 1;
    b1[1].subresourceRange.layerCount = 1;

    vkCmdPipelineBarrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                         0, 0, NULL, 0, NULL, 2, b1);
}

/* ─── Interactive window main loop ─── */
static int run_windowed(QuantumVis *qv, NuclearReaction *nr_ptr,
                        ReactorThermal *rt_ptr,
                        AtomicFission *af_ptr,
                        int W, int H, int Z, int n, int l, int m,
                        float cam_dist, float cam_theta, float cam_phi) {
    /* Mode state */
    int nuclear_mode = 0;     /* 0 = quantum, 1 = nuclear */
    int thermal_mode = 0;     /* 0 = off, 1 = thermal visualization */
    int atomic_mode  = 0;     /* 0 = off, 1 = atomic fission visualization */
    NR_ReactionType nr_type = NR_FISSION_U235;
    double prev_time = 0.0;
    int thermal_paused = 0;
    /* Create GLFW window */
    g_window = glfwCreateWindow(W, H, "YSU Quantum Wavefunction Visualizer", NULL, NULL);
    if (!g_window) { fprintf(stderr, "[QV] glfwCreateWindow failed\n"); return -1; }

    /* Create Vulkan surface */
    if (glfwCreateWindowSurface(g_instance, g_window, NULL, &g_surface) != VK_SUCCESS) {
        fprintf(stderr, "[QV] glfwCreateWindowSurface failed\n");
        return -2;
    }

    /* Verify queue supports presentation */
    VkBool32 present_ok = VK_FALSE;
    vkGetPhysicalDeviceSurfaceSupportKHR(g_phys, g_qfi, g_surface, &present_ok);
    if (!present_ok) {
        fprintf(stderr, "[QV] Queue family %u does not support presentation\n", g_qfi);
        return -3;
    }

    /* Create swapchain */
    SwapchainInfo sw;
    memset(&sw, 0, sizeof(sw));
    if (create_swapchain(W, H, &sw) != 0) return -4;

    /* Create blit command buffer (separate from quantum dispatch) */
    VkCommandPool blit_pool;
    VkCommandPoolCreateInfo cpci = {VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
    cpci.queueFamilyIndex = g_qfi;
    cpci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    vkCreateCommandPool(g_dev, &cpci, NULL, &blit_pool);

    VkCommandBuffer blit_cb;
    VkCommandBufferAllocateInfo cbai = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    cbai.commandPool        = blit_pool;
    cbai.level              = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cbai.commandBufferCount = 1;
    vkAllocateCommandBuffers(g_dev, &cbai, &blit_cb);

    /* Sync objects */
    VkSemaphore sem_image_avail, sem_render_done;
    VkFence     fence_in_flight;

    VkSemaphoreCreateInfo sci_sem = {VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
    vkCreateSemaphore(g_dev, &sci_sem, NULL, &sem_image_avail);
    vkCreateSemaphore(g_dev, &sci_sem, NULL, &sem_render_done);

    VkFenceCreateInfo fci = {VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    fci.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    vkCreateFence(g_dev, &fci, NULL, &fence_in_flight);

    /* Set scroll callback */
    glfwSetScrollCallback(g_window, scroll_cb);

    /* ── DLSS initialization ── */
    if (g_dlss_enabled) {
        int dlss_rc = dlss_init_system(qv);
        if (dlss_rc == 0) {
            g_dlss_active = 1;
        } else {
            fprintf(stderr, "[DLSS] Init failed (%d) — falling back to direct blit\n", dlss_rc);
            g_dlss_enabled = 0;
            g_dlss_active  = 0;
        }
    }

    /* ── GPU Denoise initialization ── */
    {
        int dn_rc = denoise_init(qv);
        if (dn_rc != 0) {
            fprintf(stderr, "[DENOISE] Init failed (%d) — denoising disabled\n", dn_rc);
            g_denoise_enabled = 0;
        }
    }

    /* State */
    int   frame      = 0;
    int   dirty      = 1;  /* orbital changed → regenerate grid & reset accumulation */
    float prev_theta = cam_theta;
    float prev_phi   = cam_phi;
    float prev_dist  = cam_dist;

    /* FPS tracking */
    double fps_last  = glfwGetTime();
    int    fps_count = 0;

    printf("[QV] Entering interactive window loop...\n");
    printf("[QV] Controls: drag=orbit, scroll=zoom, 1-5=n, S/P/D/F=l, +/-=m\n");
    printf("[QV]           UP/DOWN=cycle atoms, H=hydrogen mode, A=atom mode, C=color, R=reset, ESC=quit\n");
    printf("[QV]           N=nuclear mode, LEFT/RIGHT=reaction type, SPACE=play/restart\n");
    printf("[QV]           T=thermal mode, G=scram, +/-=rods, X=xenon status, SPACE=pause\n");
    printf("[QV]           U=toggle DLSS, I=DLSS info, B=toggle denoise\n");
    prev_time = glfwGetTime();

    while (!glfwWindowShouldClose(g_window)) {
        glfwPollEvents();

        /* ── Frame timing (needed early for hold-to-ramp controls) ── */
        double cur_time = glfwGetTime();
        float dt = (float)(cur_time - prev_time);
        prev_time = cur_time;
        if (dt > 0.1f) dt = 0.1f; /* clamp large dt */

        /* ── Input: mode switching (H = hydrogen, A = atom) ── */
        static int key_h_prev = 0, key_a_prev = 0;
        int kh = glfwGetKey(g_window, GLFW_KEY_H) == GLFW_PRESS;
        int ka = glfwGetKey(g_window, GLFW_KEY_A) == GLFW_PRESS;
        if (kh && !key_h_prev && Z != 0) { Z = 0; dirty = 1; printf("[QV] → Hydrogen mode\n"); }
        if (ka && !key_a_prev && Z == 0) { Z = 1; dirty = 1; printf("[QV] → Atom mode (Z=1)\n"); }
        key_h_prev = kh; key_a_prev = ka;

        /* ── Input: atom cycling (UP/DOWN arrows) ── */
        static int key_up_prev = 0, key_down_prev = 0;
        int kup   = glfwGetKey(g_window, GLFW_KEY_UP)   == GLFW_PRESS;
        int kdown = glfwGetKey(g_window, GLFW_KEY_DOWN) == GLFW_PRESS;
        if (kup   && !key_up_prev)   { if (Z > 0 && Z < 36) { Z++; dirty = 1; } else if (Z == 0) { Z = 1; dirty = 1; } }
        if (kdown && !key_down_prev) { if (Z > 1)  { Z--; dirty = 1; } }
        key_up_prev = kup; key_down_prev = kdown;

        /* ── Input: orbital keyboard controls (hydrogen mode only, not in thermal/nuclear) ── */
        if (Z == 0 && !thermal_mode && !nuclear_mode && !atomic_mode) {
            if (glfwGetKey(g_window, GLFW_KEY_1) == GLFW_PRESS && n != 1) { n = 1; l = 0; m = 0; dirty = 1; }
            if (glfwGetKey(g_window, GLFW_KEY_2) == GLFW_PRESS && n != 2) { n = 2; if (l >= n) l = n-1; if (abs(m) > l) m = 0; dirty = 1; }
            if (glfwGetKey(g_window, GLFW_KEY_3) == GLFW_PRESS && n != 3) { n = 3; if (l >= n) l = n-1; if (abs(m) > l) m = 0; dirty = 1; }
            if (glfwGetKey(g_window, GLFW_KEY_4) == GLFW_PRESS && n != 4) { n = 4; if (l >= n) l = n-1; if (abs(m) > l) m = 0; dirty = 1; }
            if (glfwGetKey(g_window, GLFW_KEY_5) == GLFW_PRESS && n != 5) { n = 5; if (l >= n) l = n-1; if (abs(m) > l) m = 0; dirty = 1; }

            static int key_s_prev = 0, key_p_prev = 0, key_d_prev = 0, key_f_prev = 0;
            int ks = glfwGetKey(g_window, GLFW_KEY_S) == GLFW_PRESS;
            int kp = glfwGetKey(g_window, GLFW_KEY_P) == GLFW_PRESS;
            int kd = glfwGetKey(g_window, GLFW_KEY_D) == GLFW_PRESS;
            int kf = glfwGetKey(g_window, GLFW_KEY_F) == GLFW_PRESS;
            if (ks && !key_s_prev && 0 < n) { l = 0; m = 0; dirty = 1; }
            if (kp && !key_p_prev && 1 < n) { l = 1; if (abs(m) > l) m = 0; dirty = 1; }
            if (kd && !key_d_prev && 2 < n) { l = 2; if (abs(m) > l) m = 0; dirty = 1; }
            if (kf && !key_f_prev && 3 < n) { l = 3; if (abs(m) > l) m = 0; dirty = 1; }
            key_s_prev = ks; key_p_prev = kp; key_d_prev = kd; key_f_prev = kf;

            static int key_plus_prev = 0, key_minus_prev = 0;
            int kplus  = glfwGetKey(g_window, GLFW_KEY_EQUAL) == GLFW_PRESS;  /* +/= key */
            int kminus = glfwGetKey(g_window, GLFW_KEY_MINUS) == GLFW_PRESS;
            if (kplus  && !key_plus_prev  && m < l)  { m++; dirty = 1; }
            if (kminus && !key_minus_prev && m > -l) { m--; dirty = 1; }
            key_plus_prev = kplus; key_minus_prev = kminus;
        }

        /* ── Atomic fission mode toggle: Q key ── */
        static int key_q_prev = 0;
        int kq = glfwGetKey(g_window, GLFW_KEY_Q) == GLFW_PRESS;
        if (kq && !key_q_prev && af_ptr != NULL) {
            atomic_mode = !atomic_mode;
            nuclear_mode = 0; thermal_mode = 0;
            if (atomic_mode) {
                atomic_fission_setup(af_ptr, af_ptr->scene);
                printf("[AF] → Atomic fission mode: scene %d\n", af_ptr->scene);
                printf("[AF]   Q=toggle  0-9=jump scene  LEFT/RIGHT=cycle  SPACE=play/pause  V=auto-tour\n");
                cam_dist = af_ptr->boxHalf * 3.0f;
            } else {
                printf("[QV] → Quantum mode\n");
                dirty = 1;
            }
            frame = 0;
        }
        key_q_prev = kq;

        /* ── Auto-tour mode: V key (cycles scenes automatically every ~10s) ── */
        static int auto_tour = 0;
        static double auto_tour_timer = 0.0;
        static int key_v_prev = 0;
        int kv = glfwGetKey(g_window, GLFW_KEY_V) == GLFW_PRESS;
        if (kv && !key_v_prev) {
            auto_tour = !auto_tour;
            auto_tour_timer = 0.0;
            if (auto_tour) {
                /* Enter atomic mode if not already */
                if (!atomic_mode && af_ptr != NULL) {
                    atomic_mode = 1;
                    nuclear_mode = 0; thermal_mode = 0;
                    atomic_fission_setup(af_ptr, af_ptr->scene);
                    cam_dist = af_ptr->boxHalf * 3.0f;
                }
                printf("[AF] ▶ Auto-tour ON — cycling all %d scenes (20s each)\n", AF_SCENE_COUNT);
            } else {
                printf("[AF] ■ Auto-tour OFF\n");
            }
            frame = 0;
        }
        key_v_prev = kv;

        if (auto_tour && atomic_mode && af_ptr) {
            auto_tour_timer += dt;
            if (auto_tour_timer > 20.0) {
                auto_tour_timer = 0.0;
                atomic_fission_next_scene(af_ptr);
                cam_dist = af_ptr->boxHalf * 3.0f;
                frame = 0;
                printf("[AF] Auto-tour → Scene %d: %s\n",
                       af_ptr->scene, atomic_fission_scene_name(af_ptr->scene));
                for (int h = 0; h < af_ptr->hud_num_lines; h++)
                    printf("  HUD| %s\n", af_ptr->hud_lines[h]);
            }
        }

        /* ── Nuclear mode toggle: N key ── */
        static int key_n_prev = 0;
        int kn = glfwGetKey(g_window, GLFW_KEY_N) == GLFW_PRESS;
        if (kn && !key_n_prev && nr_ptr != NULL) {
            nuclear_mode = !nuclear_mode;
            thermal_mode = 0; atomic_mode = 0;  /* exit other modes */
            if (nuclear_mode) {
                nuclear_reaction_setup(nr_ptr, nr_type);
                printf("[QV] → Nuclear mode: %s\n", nuclear_reaction_type_name(nr_type));
                cam_dist = nr_ptr->boxHalf * 3.0f;
            } else {
                printf("[QV] → Quantum mode\n");
                dirty = 1;
            }
            frame = 0;
        }
        key_n_prev = kn;

        /* ── Thermal mode toggle: T key ── */
        static int key_t_prev = 0;
        int kt = glfwGetKey(g_window, GLFW_KEY_T) == GLFW_PRESS;
        if (kt && !key_t_prev && rt_ptr != NULL) {
            thermal_mode = !thermal_mode;
            nuclear_mode = 0; atomic_mode = 0;  /* exit other modes */
            if (thermal_mode) {
                printf("[RT] → Thermal mode (RBMK-1000 reactor)\n");
                printf("[RT]   Power=%.1f%% P=%.1f MPa  ρ=%+.3f$ (6-group + Xe-135)\n",
                       rt_ptr->power_fraction * 100.0f,
                       rt_ptr->system_pressure / 1.0e6f,
                       rt_ptr->reactivity / RT_BETA_TOTAL);
                printf("[RT]   Xe-135: %.0f%% of equilibrium (ρ_Xe=%+.2f$)\n",
                       (rt_ptr->xe_eq > 0.0f ? rt_ptr->xenon_135 / rt_ptr->xe_eq * 100.0f : 0.0f),
                       rt_ptr->xe_reactivity / RT_BETA_TOTAL);
                printf("[RT]   Operator rods: %+.1f$\n",
                       rt_ptr->operator_rod_rho / RT_BETA_TOTAL);
                printf("[RT]   Controls: +/- = withdraw/insert rods, G = SCRAM, X = Xe status\n");
                cam_dist = rt_ptr->boxHalf * 2.5f;
            } else {
                printf("[QV] → Quantum mode\n");
                dirty = 1;
            }
            frame = 0;
        }
        key_t_prev = kt;

        /* ── Thermal mode controls ── */
        if (thermal_mode && rt_ptr) {
            /* G key = AZ-5 emergency shutdown (all 211 rods drop) */
            static int key_g_prev = 0;
            int kg = glfwGetKey(g_window, GLFW_KEY_G) == GLFW_PRESS;
            if (kg && !key_g_prev) {
                reactor_thermal_scram(rt_ptr);
                reactor_thermal_az5(rt_ptr);
                printf("[AZ-5] EMERGENCY SHUTDOWN — all 211 rods dropping!\n");
            }
            key_g_prev = kg;

            /* [ / ] = withdraw/insert operator rod group (visual per-rod animation)
             * This drives group-0 (manual) rods and simultaneously adjusts reactivity */
            static int key_lb_prev = 0, key_rb_prev = 0;
            int klb = glfwGetKey(g_window, GLFW_KEY_LEFT_BRACKET)  == GLFW_PRESS;
            int krb = glfwGetKey(g_window, GLFW_KEY_RIGHT_BRACKET) == GLFW_PRESS;
            if (klb && !key_lb_prev) {
                reactor_thermal_rods_adjust(rt_ptr, -0.05f); /* withdraw 5% */
                printf("[RODS] Group 0 withdraw — avg insertion %.0f%%\n",
                       reactor_thermal_rod_avg(rt_ptr, 0) * 100.0f);
            }
            if (krb && !key_rb_prev) {
                reactor_thermal_rods_adjust(rt_ptr, +0.05f); /* insert 5% */
                printf("[RODS] Group 0 insert  — avg insertion %.0f%%\n",
                       reactor_thermal_rod_avg(rt_ptr, 0) * 100.0f);
            }
            key_lb_prev = klb; key_rb_prev = krb;

            /* +/- = adjust operator rod position (reactivity control)
             * This simulates withdrawing (+) or inserting (-) control rods.
             * Each tap = ±0.15$ reactivity.  Hold to ramp continuously.
             * Fighting Xe-135 poisoning requires withdrawing rods (+ key). */
            static int key_tp_prev = 0, key_tm_prev = 0;
            static double power_ramp_timer = 0.0;
            int ktp = glfwGetKey(g_window, GLFW_KEY_EQUAL)       == GLFW_PRESS
                   || glfwGetKey(g_window, GLFW_KEY_KP_ADD)      == GLFW_PRESS;
            int ktm = glfwGetKey(g_window, GLFW_KEY_MINUS)       == GLFW_PRESS
                   || glfwGetKey(g_window, GLFW_KEY_KP_SUBTRACT) == GLFW_PRESS;

            float rod_step = 0.15f * RT_BETA_TOTAL;  /* 0.15$ per tap — realistic rod speed */
            int power_changed = 0;
            /* Edge-trigger: first press fires immediately */
            if (ktp && !key_tp_prev) {
                rt_ptr->operator_rod_rho += rod_step;
                if (rt_ptr->operator_rod_rho > 0.020f) rt_ptr->operator_rod_rho = 0.020f; /* max ~3$ */
                printf("[RT] Rods OUT  ρ_op=%+.4f (%+.1f$)\n",
                       rt_ptr->operator_rod_rho, rt_ptr->operator_rod_rho / RT_BETA_TOTAL);
                power_ramp_timer = 0.0;
                power_changed = 1;
            }
            if (ktm && !key_tm_prev) {
                rt_ptr->operator_rod_rho -= rod_step;
                if (rt_ptr->operator_rod_rho < -0.020f) rt_ptr->operator_rod_rho = -0.020f;
                printf("[RT] Rods IN   ρ_op=%+.4f (%+.1f$)\n",
                       rt_ptr->operator_rod_rho, rt_ptr->operator_rod_rho / RT_BETA_TOTAL);
                power_ramp_timer = 0.0;
                power_changed = 1;
            }
            /* Hold-to-ramp: after 0.4 s delay, ramp at 0.5$/s (realistic rod drive) */
            if ((ktp || ktm) && !power_changed) {
                power_ramp_timer += (double)dt;
                if (power_ramp_timer > 0.4) {
                    float ramp = 0.5f * RT_BETA_TOTAL * dt;  /* 0.5$ per second */
                    rt_ptr->operator_rod_rho += (ktp ? ramp : -ramp);
                    if (rt_ptr->operator_rod_rho >  0.020f) rt_ptr->operator_rod_rho = 0.020f;
                    if (rt_ptr->operator_rod_rho < -0.020f) rt_ptr->operator_rod_rho = -0.020f;
                    power_changed = 1;
                }
            }
            if (!ktp && !ktm) power_ramp_timer = 0.0;
            key_tp_prev = ktp; key_tm_prev = ktm;

            /* Immediate title bar update on power/rod change */
            if (power_changed) {
                char title[256];
                float rho_dollars = rt_ptr->reactivity / RT_BETA_TOTAL;
                float rod_dollars = rt_ptr->operator_rod_rho / RT_BETA_TOTAL;
                float xe_dollars  = rt_ptr->xe_reactivity / RT_BETA_TOTAL;
                snprintf(title, sizeof(title),
                         "YSU RBMK | %.1f%% %.0fMW | rho=%+.1f$ rods=%+.1f$ Xe=%+.1f$ %s",
                         rt_ptr->power_fraction * 100.0f,
                         rt_ptr->total_power_w / 1.0e6f,
                         rho_dollars, rod_dollars, xe_dollars,
                         rt_ptr->scram_active ? "SCRAM" : "");
                glfwSetWindowTitle(g_window, title);
            }

            /* X key = show Xe-135 poisoning status */
            static int key_x_prev = 0;
            int kx = glfwGetKey(g_window, GLFW_KEY_X) == GLFW_PRESS;
            if (kx && !key_x_prev) {
                float xe_ratio = (rt_ptr->xe_eq > 0.0f)
                               ? rt_ptr->xenon_135 / rt_ptr->xe_eq : 0.0f;
                float xe_dollars = rt_ptr->xe_reactivity / RT_BETA_TOTAL;
                printf("[RT] ══ Xe-135 Poisoning Status ══\n");
                printf("[RT]   I-135:  %.3e atoms/cm³\n", rt_ptr->iodine_135);
                printf("[RT]   Xe-135: %.3e atoms/cm³\n", rt_ptr->xenon_135);
                printf("[RT]   Xe/Xe_eq: %.1f%% (100%%=equilibrium at current power)\n",
                       xe_ratio * 100.0f);
                printf("[RT]   Xe reactivity: %+.4f Δk/k (%+.2f$)\n",
                       rt_ptr->xe_reactivity, xe_dollars);
                printf("[RT]   Neutron flux: %.2e n/cm²/s\n", rt_ptr->neutron_flux);
                if (xe_ratio > 1.2f)
                    printf("[RT]   ⚠ IODINE PIT — Xe above equilibrium, rods being withdrawn!\n");
                else if (xe_ratio < 0.5f && rt_ptr->power_fraction > 0.5f)
                    printf("[RT]   ⚠ Xe BURNOFF — Positive reactivity insertion!\n");
            }
            key_x_prev = kx;

            /* SPACE: pause/resume thermal simulation */
            static int key_sp2_prev = 0;
            int ksp2 = glfwGetKey(g_window, GLFW_KEY_SPACE) == GLFW_PRESS;
            if (ksp2 && !key_sp2_prev) {
                thermal_paused = !thermal_paused;
                printf("[RT] Thermal sim %s\n", thermal_paused ? "paused" : "running");
            }
            key_sp2_prev = ksp2;
        }

        /* ── Atomic fission: direct scene jump (0-9 keys) + cycling (LEFT/RIGHT) + SPACE ── */
        if (atomic_mode && af_ptr) {
            /* Number keys 0-9 jump directly to scenes 0-9 */
            static int key_num_prev[10] = {0};
            const int num_keys[10] = {
                GLFW_KEY_0, GLFW_KEY_1, GLFW_KEY_2, GLFW_KEY_3, GLFW_KEY_4,
                GLFW_KEY_5, GLFW_KEY_6, GLFW_KEY_7, GLFW_KEY_8, GLFW_KEY_9
            };
            for (int si = 0; si < 10 && si < AF_SCENE_COUNT; si++) {
                int pressed = glfwGetKey(g_window, num_keys[si]) == GLFW_PRESS;
                if (pressed && !key_num_prev[si] && af_ptr->scene != si) {
                    af_ptr->scene = (AF_SceneType)si;
                    atomic_fission_setup(af_ptr, af_ptr->scene);
                    cam_dist = af_ptr->boxHalf * 3.0f;
                    frame = 0;
                    printf("[AF] Scene → %d: %s\n", af_ptr->scene,
                           atomic_fission_scene_name(af_ptr->scene));
                    for (int h = 0; h < af_ptr->hud_num_lines; h++)
                        printf("  HUD| %s\n", af_ptr->hud_lines[h]);
                }
                key_num_prev[si] = pressed;
            }

            static int key_al_prev = 0, key_ar_prev = 0;
            int kal = glfwGetKey(g_window, GLFW_KEY_LEFT) == GLFW_PRESS;
            int kar = glfwGetKey(g_window, GLFW_KEY_RIGHT) == GLFW_PRESS;
            if (kar && !key_ar_prev) {
                atomic_fission_next_scene(af_ptr);
                cam_dist = af_ptr->boxHalf * 3.0f;
                frame = 0;
                printf("[AF] Scene → %d: %s\n", af_ptr->scene,
                       atomic_fission_scene_name(af_ptr->scene));
                for (int h = 0; h < af_ptr->hud_num_lines; h++)
                    printf("  HUD| %s\n", af_ptr->hud_lines[h]);
            }
            if (kal && !key_al_prev) {
                int prev = (int)af_ptr->scene - 1;
                if (prev < 0) prev = AF_SCENE_COUNT - 1;
                af_ptr->scene = (AF_SceneType)prev;
                atomic_fission_setup(af_ptr, af_ptr->scene);
                cam_dist = af_ptr->boxHalf * 3.0f;
                frame = 0;
                printf("[AF] Scene → %d: %s\n", af_ptr->scene,
                       atomic_fission_scene_name(af_ptr->scene));
                for (int h = 0; h < af_ptr->hud_num_lines; h++)
                    printf("  HUD| %s\n", af_ptr->hud_lines[h]);
            }
            key_al_prev = kal; key_ar_prev = kar;

            static int key_asp_prev = 0;
            int kasp = glfwGetKey(g_window, GLFW_KEY_SPACE) == GLFW_PRESS;
            if (kasp && !key_asp_prev) {
                if (af_ptr->phase == AF_PHASE_COMPLETE || !af_ptr->playing) {
                    atomic_fission_setup(af_ptr, af_ptr->scene);
                    af_ptr->playing = 1;
                    printf("[AF] Animation started\n");
                } else {
                    af_ptr->playing = !af_ptr->playing;
                    printf("[AF] Animation %s\n", af_ptr->playing ? "resumed" : "paused");
                }
                frame = 0;
            }
            key_asp_prev = kasp;
        }

        /* ── Nuclear: reaction type cycling (LEFT/RIGHT) ── */
        if (nuclear_mode) {
            static int key_left_prev = 0, key_right_prev = 0;
            int kl = glfwGetKey(g_window, GLFW_KEY_LEFT) == GLFW_PRESS;
            int kr2 = glfwGetKey(g_window, GLFW_KEY_RIGHT) == GLFW_PRESS;
            if (kr2 && !key_right_prev) {
                nr_type = (NR_ReactionType)((nr_type + 1) % NR_REACTION_COUNT);
                nuclear_reaction_setup(nr_ptr, nr_type);
                cam_dist = nr_ptr->boxHalf * 3.0f;
                frame = 0;
                printf("[QV] Reaction → %s\n", nuclear_reaction_type_name(nr_type));
            }
            if (kl && !key_left_prev) {
                nr_type = (NR_ReactionType)((nr_type + NR_REACTION_COUNT - 1) % NR_REACTION_COUNT);
                nuclear_reaction_setup(nr_ptr, nr_type);
                cam_dist = nr_ptr->boxHalf * 3.0f;
                frame = 0;
                printf("[QV] Reaction → %s\n", nuclear_reaction_type_name(nr_type));
            }
            key_left_prev = kl; key_right_prev = kr2;

            /* SPACE: play / restart animation */
            static int key_space_prev = 0;
            int ksp = glfwGetKey(g_window, GLFW_KEY_SPACE) == GLFW_PRESS;
            if (ksp && !key_space_prev) {
                if (nr_ptr->phase == NR_PHASE_DONE || !nr_ptr->playing) {
                    nuclear_reaction_setup(nr_ptr, nr_type);
                    nr_ptr->playing = 1;
                    printf("[QV] Animation started\n");
                } else {
                    nr_ptr->playing = !nr_ptr->playing;
                    printf("[QV] Animation %s\n", nr_ptr->playing ? "resumed" : "paused");
                }
                frame = 0;
            }
            key_space_prev = ksp;
        }

        /* Color mode cycling: C key */
        static int key_c_prev = 0;
        int kc = glfwGetKey(g_window, GLFW_KEY_C) == GLFW_PRESS;
        if (kc && !key_c_prev) {
            if (!nuclear_mode) {
                qv->params.color_mode = (qv->params.color_mode + 1) % 4;
                printf("[QV] Color mode → %d\n", qv->params.color_mode);
            }
            frame = 0;
        }
        key_c_prev = kc;

        /* Reset camera: R key */
        static int key_r_prev = 0;
        int kr = glfwGetKey(g_window, GLFW_KEY_R) == GLFW_PRESS;
        if (kr && !key_r_prev) {
            cam_theta = 30.0f * (float)M_PI / 180.0f;
            cam_phi   = 45.0f * (float)M_PI / 180.0f;
            cam_dist  = qv->boxHalf * 2.5f;
            frame = 0;
        }
        key_r_prev = kr;

        /* DLSS toggle: U key */
        static int key_u_prev = 0;
        int ku = glfwGetKey(g_window, GLFW_KEY_U) == GLFW_PRESS;
        if (ku && !key_u_prev && g_dlss_enabled && g_upscale_inited) {
            g_dlss_active = !g_dlss_active;
            g_hasPrevCam  = 0;  /* reset motion vector history */
            g_dlssFrame   = 0;
            frame = 0;
            printf("[DLSS] %s — %s blit from %dx%d → %dx%d\n",
                   g_dlss_active ? "ON (temporal super-res)" : "OFF (bilinear)",
                   g_dlss_active ? "DLSS" : "Bilinear",
                   g_W_lo, g_H_lo, g_W_hi, g_H_hi);
        }
        key_u_prev = ku;

        /* Denoise toggle: B key */
        static int key_b_prev = 0;
        int kb = glfwGetKey(g_window, GLFW_KEY_B) == GLFW_PRESS;
        if (kb && !key_b_prev && g_dnInited) {
            g_denoise_enabled = !g_denoise_enabled;
            frame = 0;
            printf("[DENOISE] %s (bilateral r=%d σ_s=%.1f σ_r=%.2f)\n",
                   g_denoise_enabled ? "ON" : "OFF",
                   g_dn_radius, g_dn_sigma_s, g_dn_sigma_r);
        }
        key_b_prev = kb;

        /* DLSS quality info: I key */
        static int key_i_prev = 0;
        int ki = glfwGetKey(g_window, GLFW_KEY_I) == GLFW_PRESS;
        if (ki && !key_i_prev && g_dlss_enabled) {
            printf("[DLSS] ══ DLSS Status ══\n");
            printf("[DLSS]   Active: %s\n", g_dlss_active ? "YES" : "NO");
            printf("[DLSS]   Quality: %s\n",
                   (const char *[]){"Ultra Perf(3x)","Performance(2x)","Balanced(1.7x)","Quality(1.5x)","Ultra(1.3x)"}[g_dlss_quality]);
            printf("[DLSS]   Internal: %dx%d → Display: %dx%d\n", g_W_lo, g_H_lo, g_W_hi, g_H_hi);
            printf("[DLSS]   Mode: %s\n", g_upscale.has_neural_weights ? "Neural" : "Temporal Fallback");
            printf("[DLSS]   Frame: %u  Jitter phase: %u\n", g_dlssFrame, g_dlssFrame % 16);
        }
        key_i_prev = ki;

        /* ESC → close */
        if (glfwGetKey(g_window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
            glfwSetWindowShouldClose(g_window, 1);

        /* ── Mouse orbit ── */
        double mx, my;
        glfwGetCursorPos(g_window, &mx, &my);
        if (!g_mouse_init) { g_last_mx = mx; g_last_my = my; g_mouse_init = 1; }

        int lmb = glfwGetMouseButton(g_window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;
        if (lmb) {
            float dx = (float)(mx - g_last_mx);
            float dy = (float)(my - g_last_my);
            cam_phi   += dx * 0.005f;
            cam_theta -= dy * 0.005f;
            /* Clamp theta to avoid gimbal lock at poles */
            if (cam_theta < 0.05f)            cam_theta = 0.05f;
            if (cam_theta > (float)M_PI - 0.05f) cam_theta = (float)M_PI - 0.05f;
        }
        g_last_mx = mx;
        g_last_my = my;

        /* Scroll zoom */
        if (g_scroll_accum != 0.0f) {
            cam_dist *= (1.0f - g_scroll_accum * 0.08f);
            if (cam_dist < 2.0f)   cam_dist = 2.0f;
            if (cam_dist > 500.0f) cam_dist = 500.0f;
            g_scroll_accum = 0.0f;
        }

        /* Detect camera movement → reset accumulation */
        int cam_moved = (fabsf(cam_theta - prev_theta) > 1e-5f ||
                         fabsf(cam_phi   - prev_phi)   > 1e-5f ||
                         fabsf(cam_dist  - prev_dist)  > 1e-5f);
        if (cam_moved) { frame = 0; prev_theta = cam_theta; prev_phi = cam_phi; prev_dist = cam_dist; }

        /* If orbital changed, reconfigure & regenerate grid */
        if (dirty) {
            if (Z > 0)
                quantum_vis_set_atom(qv, Z);
            else
                quantum_vis_set_hydrogen(qv, n, l, m);
            /* Reset step_size to auto half-voxel (may have been overridden by atomic/nuclear modes) */
            qv->params.step_size  = 0.0f;
            qv->params.max_steps  = 2048;
            /* Auto-adjust camera to fit new box */
            cam_dist = qv->boxHalf * 2.5f;
            frame = 0;
            dirty = 0;
            char title[256];
            if (Z > 0)
                snprintf(title, sizeof(title), "YSU Quantum — %s (Z=%d) %s",
                         element_name(Z), Z, electron_config(Z));
            else
                snprintf(title, sizeof(title), "YSU Quantum — %d%s (m=%d)", n, orbital_letter(l), m);
            glfwSetWindowTitle(g_window, title);
        }

        /* ── Build camera ── */
        QV_Camera cam;
        build_camera(&cam, cam_dist, cam_theta, cam_phi);

        /* ── Nuclear mode: update physics + dispatch density ── */

        if (atomic_mode && af_ptr) {
            /* Update atomic fission simulation */
            atomic_fission_update(af_ptr, dt);
            /* Write atomic density field to vis SSBOs */
            atomic_fission_visualize(af_ptr, g_queue);

            /* Configure raymarch for atomic-scale rendering */
            qv->needsGridUpdate = 0;
            qv->boxHalf = af_ptr->boxHalf;
            qv->params.color_mode     = 7;     /* atomic scale visualization */
            qv->params.density_mult   = 3.0f;  /* low: let shader orbital math control shape */
            qv->params.emission_scale = 1.5f;  /* subtle glow, colors stay saturated */
            qv->params.gamma          = 0.08f;
            qv->params.output_mode    = 0;
            /* Half-voxel step for smoother sampling (reduces voxel grid artifacts) */
            qv->params.step_size      = af_ptr->boxHalf / (float)qv->gridDim;
            qv->params.max_steps      = 2048;
            frame = 0;  /* animated */

            /* Title bar */
            static int af_title_ctr = 0;
            if (++af_title_ctr % 10 == 0) {
                char title[256];
                snprintf(title, sizeof(title),
                         "YSU Atomic | %s | %s%s",
                         atomic_fission_scene_name(af_ptr->scene),
                         af_ptr->hud_num_lines > 0 ? af_ptr->hud_lines[0] : "",
                         auto_tour ? " [AUTO-TOUR]" : "");
                glfwSetWindowTitle(g_window, title);
            }
        } else if (thermal_mode && rt_ptr) {
            /* Update thermal simulation */
            if (!thermal_paused) {
                reactor_thermal_update(rt_ptr, dt);
            }
            /* Write temperature field to vis SSBOs */
            reactor_thermal_visualize(rt_ptr, g_queue);

            /* Configure raymarch for thermal rendering */
            qv->needsGridUpdate = 0;  /* skip wavefunction pass */
            qv->boxHalf = rt_ptr->boxHalf;
            qv->params.color_mode     = 6;    /* RBMK material visualization */
            qv->params.density_mult   = 10.0f;
            qv->params.step_size      = rt_ptr->boxHalf / (float)qv->gridDim;
            qv->params.max_steps      = 2048;
            /* Emission scales with power — brighter = more fission */
            float pwr_scale = rt_ptr->power_fraction;
            if (pwr_scale < 0.05f) pwr_scale = 0.05f;
            if (pwr_scale > 5.0f) pwr_scale = 5.0f;
            qv->params.emission_scale = 1.5f + 1.5f * pwr_scale;
            qv->params.gamma          = 0.06f;
            qv->params.output_mode    = 0;
            frame = 0;  /* always reset — animated */
        } else if (nuclear_mode) {
            nuclear_reaction_update(nr_ptr, dt);
            nuclear_reaction_dispatch(nr_ptr, g_queue);

            /* Configure raymarch for nuclear rendering */
            qv->needsGridUpdate = 0;  /* skip wavefunction pass */
            qv->boxHalf = nr_ptr->boxHalf;
            qv->params.color_mode     = 4;    /* nuclear coloring */
            qv->params.density_mult   = 3.0f;
            qv->params.emission_scale = 6.0f;
            qv->params.gamma          = 0.06f;
            qv->params.output_mode    = 0;
            qv->params.step_size      = nr_ptr->boxHalf / (float)qv->gridDim;
            qv->params.max_steps      = 2048;
            frame = 0;  /* always reset accumulation (animated) */
        }

        /* ── DLSS: Apply temporal jitter before dispatch ── */
        if (g_dlss_active && g_upscale_inited) {
            YsuJitter jitter = ysu_upscale_jitter(g_dlssFrame);
            qv->params.jitter_x = jitter.x;
            qv->params.jitter_y = jitter.y;
        } else {
            qv->params.jitter_x = 0.0f;
            qv->params.jitter_y = 0.0f;
        }

        /* ── Dispatch compute (wavefunction grid + raymarch) ── */
        quantum_vis_dispatch(qv, g_queue, &cam, frame);

        /* ── GPU bilateral denoise (runs on low-res outImage before DLSS) ── */
        if (g_denoise_enabled && g_dnInited) {
            /* Distance-adaptive denoise: when camera is far from the volume,
             * the 128³ voxel grid produces sub-pixel patterns.
             * Scale the filter radius and sigma with viewing distance. */
            float dist_ratio = cam_dist / qv->boxHalf;  /* ~2.5 close, >5 far */
            int need_strong = (atomic_mode || nuclear_mode || thermal_mode);
            int saved_radius  = g_dn_radius;
            float saved_sr    = g_dn_sigma_r;
            float saved_ss    = g_dn_sigma_s;

            /* Base params scale with distance */
            int dist_extra = (int)((dist_ratio - 2.5f) * 0.6f);
            if (dist_extra < 0) dist_extra = 0;
            if (dist_extra > 6) dist_extra = 6;

            if (need_strong) {
                g_dn_radius  = 4 + dist_extra;
                g_dn_sigma_s = 3.5f + dist_extra * 0.5f;
                g_dn_sigma_r = 0.35f + dist_extra * 0.04f;
            } else {
                /* Quantum orbital mode: gentle at close range, stronger at distance */
                g_dn_radius  = 3 + dist_extra;
                g_dn_sigma_s = 2.5f + dist_extra * 0.5f;
                g_dn_sigma_r = 0.25f + dist_extra * 0.04f;
            }

            VkCommandBuffer dn_cb;
            VkCommandBufferAllocateInfo dn_cba = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
            dn_cba.commandPool = qv->cmdPool;
            dn_cba.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            dn_cba.commandBufferCount = 1;
            vkAllocateCommandBuffers(g_dev, &dn_cba, &dn_cb);
            VkCommandBufferBeginInfo dn_cbi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
            dn_cbi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
            vkBeginCommandBuffer(dn_cb, &dn_cbi);

            /* First H+V pass */
            denoise_cmd_record(dn_cb, qv->imageW, qv->imageH);

            /* No double pass — single H+V is enough with half-voxel stepping */

            vkEndCommandBuffer(dn_cb);
            VkSubmitInfo dn_si = {VK_STRUCTURE_TYPE_SUBMIT_INFO};
            dn_si.commandBufferCount = 1;
            dn_si.pCommandBuffers = &dn_cb;
            vkQueueSubmit(g_queue, 1, &dn_si, VK_NULL_HANDLE);
            vkQueueWaitIdle(g_queue);
            vkFreeCommandBuffers(g_dev, qv->cmdPool, 1, &dn_cb);

            /* Restore default params for next frame's quantum orbital mode */
            g_dn_radius  = saved_radius;
            g_dn_sigma_r = saved_sr;
            g_dn_sigma_s = saved_ss;
        }

        frame++;

        /* ── Wait for previous present, acquire swapchain image ── */
        vkWaitForFences(g_dev, 1, &fence_in_flight, VK_TRUE, UINT64_MAX);
        vkResetFences(g_dev, 1, &fence_in_flight);

        uint32_t imgIdx = 0;
        VkResult r = vkAcquireNextImageKHR(g_dev, sw.swapchain, UINT64_MAX,
                                           sem_image_avail, VK_NULL_HANDLE, &imgIdx);
        if (r == VK_ERROR_OUT_OF_DATE_KHR) continue;
        if (r != VK_SUCCESS && r != VK_SUBOPTIMAL_KHR) {
            fprintf(stderr, "[QV] vkAcquireNextImageKHR failed: %d\n", r);
            break;
        }

        /* ── Record blit command buffer (with optional DLSS) ── */
        vkResetCommandBuffer(blit_cb, 0);
        VkCommandBufferBeginInfo cbi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        vkBeginCommandBuffer(blit_cb, &cbi);

        if (g_dlss_active && g_upscale_inited) {
            /* DLSS path: motion gen → 3-pass upscale → blit upscaled */
            dlss_cmd_record(blit_cb, qv, &cam, dt, g_dlssFrame);
            cmd_blit_to_swapchain_scaled(blit_cb,
                g_dlssOutImage, VK_IMAGE_LAYOUT_GENERAL,
                g_W_hi, g_H_hi,
                sw.images[imgIdx], sw.extent, VK_FILTER_NEAREST);

            /* Store camera for next frame's motion vectors */
            g_prevCam = cam;
            g_hasPrevCam = 1;
            g_dlssFrame++;
        } else if (g_dlss_enabled && !g_dlss_active) {
            /* DLSS disabled via U key — bilinear blit from low-res for comparison */
            cmd_blit_to_swapchain_scaled(blit_cb,
                qv->outImage, VK_IMAGE_LAYOUT_GENERAL,
                g_W_lo, g_H_lo,
                sw.images[imgIdx], sw.extent, VK_FILTER_LINEAR);
        } else {
            /* No DLSS — direct blit (same resolution) */
            cmd_blit_to_swapchain(blit_cb, qv->outImage, sw.images[imgIdx], sw.extent);
        }

        vkEndCommandBuffer(blit_cb);

        /* ── Submit with semaphore sync ── */
        VkPipelineStageFlags wait_stage = (g_dlss_active && g_upscale_inited)
            ? VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
            : VK_PIPELINE_STAGE_TRANSFER_BIT;
        VkSubmitInfo si = {VK_STRUCTURE_TYPE_SUBMIT_INFO};
        si.waitSemaphoreCount   = 1;
        si.pWaitSemaphores      = &sem_image_avail;
        si.pWaitDstStageMask    = &wait_stage;
        si.commandBufferCount   = 1;
        si.pCommandBuffers      = &blit_cb;
        si.signalSemaphoreCount = 1;
        si.pSignalSemaphores    = &sem_render_done;

        vkQueueSubmit(g_queue, 1, &si, fence_in_flight);

        /* ── Present ── */
        VkPresentInfoKHR pi = {VK_STRUCTURE_TYPE_PRESENT_INFO_KHR};
        pi.waitSemaphoreCount = 1;
        pi.pWaitSemaphores    = &sem_render_done;
        pi.swapchainCount     = 1;
        pi.pSwapchains        = &sw.swapchain;
        pi.pImageIndices      = &imgIdx;

        r = vkQueuePresentKHR(g_queue, &pi);
        if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR) {
            /* Could recreate swapchain here; for now just continue */
        }

        /* ── FPS display ── */
        fps_count++;
        double now = glfwGetTime();
        if (now - fps_last >= 1.0) {
            char title[256];
            if (thermal_mode && rt_ptr) {
                /* Reactivity in dollars: ρ/β  (1$ = prompt critical) */
                float rho_dollars = rt_ptr->reactivity / RT_BETA_TOTAL;
                float rod_dollars = rt_ptr->operator_rod_rho / RT_BETA_TOTAL;
                float xe_dollars  = rt_ptr->xe_reactivity / RT_BETA_TOTAL;
                snprintf(title, sizeof(title),
                         "YSU RBMK | %.1f%% %.0fMW | rho=%+.1f$ rods=%+.1f$ Xe=%+.1f$ %s [%d FPS]",
                         rt_ptr->power_fraction * 100.0f,
                         rt_ptr->total_power_w / 1.0e6f,
                         rho_dollars, rod_dollars, xe_dollars,
                         rt_ptr->scram_active ? "SCRAM" : "",
                         fps_count);
            }
            else if (nuclear_mode)
                snprintf(title, sizeof(title), "YSU Nuclear — %s — %s (t=%.1fs)  [%d FPS]",
                         nuclear_reaction_type_name(nr_ptr->reactionType),
                         nuclear_reaction_phase_name(nr_ptr->phase),
                         nr_ptr->time, fps_count);
            else if (Z > 0)
                snprintf(title, sizeof(title), "YSU Quantum — %s (Z=%d) %s  [%d FPS, frame %d]%s",
                         element_name(Z), Z, electron_config(Z), fps_count, frame,
                         g_dlss_active ? " [DLSS]" : "");
            else
                snprintf(title, sizeof(title), "YSU Quantum — %d%s (m=%d)  [%d FPS, frame %d]%s",
                         n, orbital_letter(l), m, fps_count, frame,
                         g_dlss_active ? " [DLSS]" : "");
            glfwSetWindowTitle(g_window, title);
            fps_count = 0;
            fps_last = now;
        }
    }

    /* ── Cleanup DLSS resources ── */
    vkDeviceWaitIdle(g_dev);
    denoise_cleanup();
    dlss_cleanup();

    /* ── Cleanup window resources ── */
    vkDestroySemaphore(g_dev, sem_image_avail, NULL);
    vkDestroySemaphore(g_dev, sem_render_done, NULL);
    vkDestroyFence(g_dev, fence_in_flight, NULL);
    vkDestroyCommandPool(g_dev, blit_pool, NULL);
    destroy_swapchain(&sw);

    return 0;
}

#endif /* QV_ENABLE_WINDOW */

/* ═══════════════════════════════════════════════════════════════════════
 *  Main
 * ═══════════════════════════════════════════════════════════════════════ */
int main(void) {
    printf("═══════════════════════════════════════════════════════════\n");
    printf("  YSU Engine — Quantum Wavefunction Visualization\n");
    printf("  Schrödinger equation → GPU volume rendering\n");
    printf("═══════════════════════════════════════════════════════════\n\n");

    int W    = env_int("YSU_QV_W", 800);
    int H    = env_int("YSU_QV_H", 600);
    int grid = env_int("YSU_QV_GRID", 256);
    int Z    = env_int("YSU_QV_ATOM", 0);
    int n    = env_int("YSU_QV_N", 3);
    int l    = env_int("YSU_QV_L", 2);
    int m    = env_int("YSU_QV_M", 0);

    float cam_dist  = env_float("YSU_QV_CAM_DIST", 0.0f);
    float cam_theta = env_float("YSU_QV_CAM_THETA", 30.0f) * (float)M_PI / 180.0f;
    float cam_phi   = env_float("YSU_QV_CAM_PHI",   45.0f) * (float)M_PI / 180.0f;

    /* DLSS configuration — compute internal render resolution */
    g_dlss_enabled = env_bool("YSU_DLSS", 1);
    g_dlss_quality = env_int("YSU_DLSS_QUALITY", YSU_UPSCALE_QUALITY_BALANCED);
    if (g_dlss_quality < 0 || g_dlss_quality >= YSU_UPSCALE_QUALITY_COUNT)
        g_dlss_quality = YSU_UPSCALE_QUALITY_BALANCED;

    g_W_hi = W;  g_H_hi = H;
    if (g_dlss_enabled) {
        float scale = ysu_upscale_quality_factor((YsuUpscaleQuality)g_dlss_quality);
        g_W_lo = (int)(W * scale + 0.5f);
        g_H_lo = (int)(H * scale + 0.5f);
        /* Round up to 16 for workgroup alignment */
        g_W_lo = (g_W_lo + 15) & ~15;
        g_H_lo = (g_H_lo + 15) & ~15;
        if (g_W_lo < 64) g_W_lo = 64;
        if (g_H_lo < 64) g_H_lo = 64;
        printf("[DLSS] Enabled: quality=%d, internal %dx%d → display %dx%d (%.1fx)\n",
               g_dlss_quality, g_W_lo, g_H_lo, g_W_hi, g_H_hi,
               (float)g_W_hi / (float)g_W_lo);
    } else {
        g_W_lo = W;
        g_H_lo = H;
    }

    /* Render resolution: low-res when DLSS enabled, full when not */
    int renderW = g_W_lo;
    int renderH = g_H_lo;

#ifdef QV_ENABLE_WINDOW
    int windowed = env_bool("YSU_QV_WINDOW", 1); /* default ON when compiled with QV_ENABLE_WINDOW */
#else
    int windowed = 0;
#endif

    if (init_vulkan(windowed) != 0) return 1;

    QuantumVis qv;
    memset(&qv, 0, sizeof(qv));
    qv.gridDim = grid;
    if (quantum_vis_init(&qv, g_phys, g_dev, g_qfi, renderW, renderH) != 0) {
        fprintf(stderr, "[QV] Init failed\n");
        cleanup_vulkan();
        return 1;
    }

    /* Configure orbital(s) */
    if (Z > 0) {
        printf("[QV] Visualizing atom: %s (Z=%d) — %s\n", element_name(Z), Z, electron_config(Z));
        quantum_vis_set_atom(&qv, Z);
    } else {
        printf("[QV] Visualizing hydrogen orbital: %d%s (m=%d)\n", n, orbital_letter(l), m);
        quantum_vis_set_hydrogen(&qv, n, l, m);
    }

    /* Override params from env */
    qv.params.density_mult   = env_float("YSU_QV_DENSITY", qv.params.density_mult);
    qv.params.gamma          = env_float("YSU_QV_GAMMA",   qv.params.gamma);
    qv.params.color_mode     = env_int("YSU_QV_COLOR",     qv.params.color_mode);
    qv.params.output_mode    = env_int("YSU_QV_MODE",      qv.params.output_mode);
    qv.params.emission_scale = env_float("YSU_QV_EMISSION", qv.params.emission_scale);

    /* Camera setup: spherical coordinates around origin */
    if (cam_dist <= 0.0f) cam_dist = qv.boxHalf * 2.5f;

    printf("[QV] Camera: dist=%.1f a₀, θ=%.0f° φ=%.0f°\n",
           cam_dist, cam_theta * 180.0f / (float)M_PI,
           cam_phi * 180.0f / (float)M_PI);
    printf("[QV] Grid: %d³ (%d voxels), box=±%.1f a₀\n",
           qv.gridDim, qv.gridDim * qv.gridDim * qv.gridDim, qv.boxHalf);
    printf("[QV] Params: density=%.0f gamma=%.2f emission=%.1f color_mode=%d\n",
           qv.params.density_mult, qv.params.gamma,
           qv.params.emission_scale, qv.params.color_mode);

#ifdef QV_ENABLE_WINDOW
    if (windowed) {
        printf("[QV] Mode: interactive window\n");
        /* Initialize nuclear reaction system (shares density/signed SSBOs) */
        NuclearReaction nr;
        int nr_ok = nuclear_reaction_init(&nr, g_phys, g_dev, g_qfi,
                                          qv.densityBuf, qv.signedBuf, qv.gridDim);
        if (nr_ok != 0) {
            fprintf(stderr, "[NR] Nuclear reaction init failed (%d) \u2014 nuclear mode disabled\n", nr_ok);
        } else {
            printf("[NR] Nuclear reaction system ready (press N to activate)\n");
        }

        /* Initialize reactor thermal system (shares density/signed SSBOs) */
        ReactorThermal rt;
        int rt_ok = reactor_thermal_init(&rt, g_phys, g_dev, g_qfi,
                                         qv.densityBuf, qv.signedBuf, qv.gridDim);
        if (rt_ok != 0) {
            fprintf(stderr, "[RT] Reactor thermal init failed (%d) \u2014 thermal mode disabled\n", rt_ok);
        } else {
            printf("[RT] Reactor thermal system ready (press T to activate)\n");
        }

        /* Initialize atomic fission system (shares density/signed SSBOs) */
        AtomicFission af;
        int af_ok = atomic_fission_init(&af, g_phys, g_dev, g_qfi,
                                        qv.densityBuf, qv.signedBuf, qv.gridDim);
        if (af_ok != 0) {
            fprintf(stderr, "[AF] Atomic fission init failed (%d) \u2014 atomic mode disabled\n", af_ok);
        } else {
            printf("[AF] Atomic fission system ready (press Q to activate)\n");
        }

        int ret = run_windowed(&qv, nr_ok == 0 ? &nr : NULL,
                               rt_ok == 0 ? &rt : NULL,
                               af_ok == 0 ? &af : NULL,
                               W, H, Z, n, l, m, cam_dist, cam_theta, cam_phi);
        if (af_ok == 0) atomic_fission_free(&af);
        if (rt_ok == 0) reactor_thermal_free(&rt);
        if (nr_ok == 0) nuclear_reaction_free(&nr);
        quantum_vis_free(&qv, g_dev);
        cleanup_vulkan();
        return ret < 0 ? 1 : 0;
    }
#endif

    /* ─── Headless mode: progressive render → PPM ─── */
    printf("[QV] Mode: headless (rendering to PPM)\n");
    QV_Camera cam;
    build_camera(&cam, cam_dist, cam_theta, cam_phi);

    int num_frames = env_int("YSU_QV_FRAMES", 16);
    printf("[QV] Rendering %d frames (progressive accumulation)...\n", num_frames);

    for (int f = 0; f < num_frames; f++) {
        quantum_vis_dispatch(&qv, g_queue, &cam, f);
        if ((f + 1) % 4 == 0 || f == num_frames - 1)
            printf("[QV]   frame %d/%d\n", f + 1, num_frames);
    }

    /* Readback and write */
    float *rgba = (float *)malloc((size_t)W * H * 4 * sizeof(float));
    if (!rgba) { fprintf(stderr, "[QV] OOM\n"); return 1; }

    quantum_vis_readback(&qv, g_queue, rgba, W, H);

    /* Write PPM */
    char filename[256];
    if (Z > 0) {
        snprintf(filename, sizeof(filename), "quantum_Z%d.ppm", Z);
    } else {
        snprintf(filename, sizeof(filename), "quantum_%d%s_m%d.ppm",
                 n, orbital_letter(l), m);
    }
    write_ppm(filename, W, H, rgba);

    free(rgba);
    quantum_vis_free(&qv, g_dev);
    cleanup_vulkan();

    printf("\n[QV] Done. Output: %s\n", filename);
    return 0;
}
