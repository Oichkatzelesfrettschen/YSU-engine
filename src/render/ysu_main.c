// ysu_main.c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <float.h>

// Core
#include "vec3.h"
#include "camera.h"
#include "render.h"
#include "image.h"

// NeRF integration helpers (defined in nerf_simd_integration.c)
void ysu_nerf_init(const char *hashgrid_path, const char *occ_path, uint32_t width, uint32_t height);
void ysu_nerf_shutdown(void);

// Neural stage-1
#include "neural_denoise.h"
#include "gbuffer_dump.h"

// BVH baseline (CPU)
#include "bvh.h"
#include "sphere.h"

// Scene loader
#include "sceneloader.h"

// 360 render prototype (no header)
void ysu_render_360(const Camera *cam, const char *out_ppm);

// BVH counters (bvh.c)
extern uint64_t g_bvh_node_visits;
extern uint64_t g_bvh_aabb_tests;

// -------------------------
// helpers
// -------------------------
static int env_int(const char *name, int defv) {
    const char *s = getenv(name);
    if (!s || !s[0]) return defv;
    return atoi(s);
}

static void print_cfg(int w, int h, int spp, int depth, int threads, int tile) {
    printf("[main] CFG: W=%d H=%d SPP=%d DEPTH=%d THREADS=%d TILE=%d\n",
           w, h, spp, depth, threads, tile);
}

// -------------------------
// deterministic RNG (xorshift32) for baseline (legacy; baseline now comes from scene.txt)
// -------------------------
static inline uint32_t xs32(uint32_t *s) {
    uint32_t x = *s;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *s = x;
    return x;
}
static inline float frand01(uint32_t *s) {
    // [0,1)
    return (xs32(s) >> 8) * (1.0f / 16777216.0f);
}

// -------------------------
// BVH baseline: load spheres from scene file
// -------------------------
static void ysu_run_cpu_bvh_baseline(const Camera *cam, int w, int h) {
    printf("[BVH] baseline start...\n");

    // Scene path priority:
    // 1) YSU_BASELINE_SCENE env
    // 2) ./scene.txt
    // 3) ./DATA/scene.txt
    const char *scene_path = getenv("YSU_BASELINE_SCENE");
    const int MAXS = 20000;

    SceneSphere *tmp = (SceneSphere*)malloc(sizeof(SceneSphere) * (size_t)MAXS);
    if (!tmp) {
        printf("[BVH] baseline: tmp malloc failed\n");
        return;
    }

    int N = 0;

    if (scene_path && scene_path[0]) {
        N = load_scene(scene_path, tmp, MAXS);
        if (N <= 0) {
            printf("[BVH] baseline: load_scene failed (%s)\n", scene_path);
        }
    } else {
        // Try ./scene.txt first
        N = load_scene("./scene.txt", tmp, MAXS);
        if (N <= 0) {
            // Then ./DATA/scene.txt
            N = load_scene("./DATA/scene.txt", tmp, MAXS);
        }
    }

    if (N <= 0) {
        printf("[BVH] baseline: no spheres loaded (set YSU_BASELINE_SCENE or provide scene.txt)\n");
        free(tmp);
        printf("[BVH] baseline end.\n");
        return;
    }

    Sphere *spheres = (Sphere*)malloc(sizeof(Sphere) * (size_t)N);
    if (!spheres) {
        printf("[BVH] baseline: spheres malloc failed\n");
        free(tmp);
        printf("[BVH] baseline end.\n");
        return;
    }

    // SceneSphere -> Sphere (albedo not used here; mat_id=0)
    for (int i = 0; i < N; i++) {
        spheres[i] = sphere_create(tmp[i].center, tmp[i].radius, 0);
    }

    free(tmp);

    // Build BVH (sorts spheres in-place)
    bvh_node *root = bvh_build(spheres, 0, N);
    if (!root) {
        printf("[BVH] baseline: build failed\n");
        free(spheres);
        printf("[BVH] baseline end.\n");
        return;
    }

    /* ===== PASS-2  ===== */
    bvh_assign_ids(root);

    const char* pol = getenv("YSU_BVH_POLICY");
    if (pol && pol[0]) {
        bvh_load_policy_csv(pol, root);
    } else {
        printf("[BVH] policy: YSU_BVH_POLICY not set\n");
    }
    /* ===== PASS-2 (END) ===== */

    // Reset counters
    g_bvh_node_visits = 0;
    g_bvh_aabb_tests  = 0;

    uint64_t rays = 0;
    HitRecord rec;

    for (int py = 0; py < h; ++py) {
        for (int px = 0; px < w; ++px) {
            float u = (w > 1) ? ((float)px / (float)(w - 1)) : 0.5f;
            float v = (h > 1) ? ((float)py / (float)(h - 1)) : 0.5f;

            Ray rray = camera_get_ray(*cam, u, v);

            rays++;
            (void)bvh_hit(root, spheres, &rray, 0.001f, FLT_MAX, &rec);
        }
    }

    printf("===== BVH BASELINE (%d spheres) =====\n", N);
    printf("Rays        : %llu\n", (unsigned long long)rays);
    printf("Node visits : %llu\n", (unsigned long long)g_bvh_node_visits);
    printf("AABB tests  : %llu\n", (unsigned long long)g_bvh_aabb_tests);
    if (rays) {
        printf("Avg node / ray : %.2f\n", (double)g_bvh_node_visits / (double)rays);
    }

    bvh_dump_stats("baseline_bvh.csv", root);
    printf("[BVH] wrote baseline_bvh.csv\n");

    bvh_free(root);
    free(spheres);

    printf("[BVH] baseline end.\n");
}

int main(void)
{
    printf("[main] START\n");

    // -------------------------
    // Config (env)
    // -------------------------
    int image_width       = env_int("YSU_W", 800);
    int image_height      = env_int("YSU_H", 450);
    int samples_per_pixel = env_int("YSU_SPP", 64);
    int max_depth         = env_int("YSU_DEPTH", 8);
    int thread_count      = env_int("YSU_THREADS", 0); // 0 => auto
    int tile_size         = env_int("YSU_TILE", 32);

    if (image_width < 1) image_width = 1;
    if (image_height < 1) image_height = 1;
    if (samples_per_pixel < 1) samples_per_pixel = 1;
    if (max_depth < 1) max_depth = 1;
    if (tile_size < 4) tile_size = 4;

    print_cfg(image_width, image_height, samples_per_pixel, max_depth, thread_count, tile_size);

    // -------------------------
    // Allocate framebuffer (HDR)
    // -------------------------
    Vec3 *pixels = (Vec3*)calloc((size_t)image_width * (size_t)image_height, sizeof(Vec3));
    if (!pixels) {
        printf("[main] ERROR: could not allocate pixels (%dx%d)\n", image_width, image_height);
        return 1;
    }

    // -------------------------
    // Camera
    // -------------------------
    float aspect_ratio   = (float)image_width / (float)image_height;
    float viewport_h     = 2.0f;
    float focal_length   = 1.0f;
    Camera cam = camera_create(aspect_ratio, viewport_h, focal_length);

    /* For NeRF mode, reposition camera outside the scene bounds looking inward */
    if (getenv("YSU_NERF_HASHGRID")) {
        float nerf_bounds = 4.0f;
        const char *bounds_s = getenv("YSU_NERF_BOUNDS");
        if (bounds_s) nerf_bounds = (float)atof(bounds_s);
        
        /* Position camera at oblique angle for better NeRF view */
        float cam_dist = nerf_bounds * 1.5f;  /* 1.5x bounds for good framing */
        
        /* Check if user specified custom camera position */
        const char *cam_pos_s = getenv("YSU_NERF_CAM");
        float cx = 0.0f, cy = 0.0f, cz = cam_dist;
        if (cam_pos_s) {
            sscanf(cam_pos_s, "%f,%f,%f", &cx, &cy, &cz);
        }
        cam.origin = vec3(cx, cy, cz);
        
        /* Recalculate lower_left_corner for new origin */
        float w = aspect_ratio * viewport_h;
        cam.horizontal = vec3(w, 0.0f, 0.0f);
        cam.vertical = vec3(0.0f, viewport_h, 0.0f);
        cam.lower_left_corner = vec3_sub(
            vec3_sub(
                vec3_sub(cam.origin, vec3_scale(cam.horizontal, 0.5f)),
                vec3_scale(cam.vertical, 0.5f)
            ),
            vec3(0.0f, 0.0f, focal_length)
        );
        
        printf("[main] NeRF camera: origin=(%.2f, %.2f, %.2f), looking toward origin\n", cx, cy, cz);
    }

    // -------------------------
    // Render
    // -------------------------
    printf("[main] calling render...\n");

    /* Check if CPU NeRF mode is enabled */
    if (getenv("YSU_NERF_HASHGRID")) {
        const char *hashgrid_path = getenv("YSU_NERF_HASHGRID");
        const char *occ_path = getenv("YSU_NERF_OCC");
        printf("[main] NeRF CPU mode enabled, skipping traditional raytracing\n");

        if (hashgrid_path && occ_path) {
            ysu_nerf_init(hashgrid_path, occ_path, (uint32_t)image_width, (uint32_t)image_height);
        }

        render_nerf_cpu(pixels,
                        image_width,
                        image_height,
                        cam);

        /* Shutdown any NeRF global resources allocated by ysu_nerf_init */
        ysu_nerf_shutdown();
    } else if (thread_count > 0) {
        render_scene_mt(pixels,
                        image_width,
                        image_height,
                        cam,
                        samples_per_pixel,
                        max_depth,
                        thread_count,
                        tile_size);
    } else {
        render_scene_st(pixels,
                        image_width,
                        image_height,
                        cam,
                        samples_per_pixel,
                        max_depth);
    }
    // -------------------------
    // Neural denoise (if enabled internally)
    // -------------------------
    ysu_neural_denoise_maybe(pixels, image_width, image_height);

    // Optional dump (toggle: YSU_DUMP_RGB=1)
    if (getenv("YSU_DUMP_RGB")) {
        // if no real implementation, stub below returns 0
        (void)ysu_dump_rgb32("output_color.ysub", pixels, image_width, image_height);
    }

    // -------------------------
    // Output PNG (needs u8)
    // -------------------------
    unsigned char* rgb8 = image_rgb_from_hdr(pixels, image_width, image_height);
    if (!rgb8) {
        printf("[main] ERROR: image_rgb_from_hdr failed\n");
    } else {
        image_write_png("output.png", image_width, image_height, rgb8);
        printf("[main] wrote output.png\n");
        free(rgb8);
    }

    free(pixels);

    // -------------------------
    // 360 render
    // -------------------------
    printf("[main] calling ysu_render_360...\n");
    ysu_render_360(&cam, "output_360.ppm");
    printf("YSU 360: wrote output_360.png\n");
    printf("YSU 360: tamam.\n");
    printf("[main] wrote output_360.ppm\n");

    // -------------------------
    // BVH baseline (scene.txt)
    // -------------------------
    ysu_run_cpu_bvh_baseline(&cam, image_width, image_height);

    printf("[main] END\n");
    return 0;
}

// `ysu_dump_rgb32` is provided by gbuffer_dump.c; no stub here.
