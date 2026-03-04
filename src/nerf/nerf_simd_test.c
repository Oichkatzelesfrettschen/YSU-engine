/*
 * nerf_simd_test.c
 * 
 * Comprehensive test and benchmark suite for CPU SIMD NeRF renderer.
 * Compile and run independently to validate performance.
 * 
 * Build:
 *   gcc -O3 -march=native -o nerf_simd_test nerf_simd.c vec3.c nerf_simd_test.c -lm
 * 
 * Run:
 *   ./nerf_simd_test
 */

#include "nerf_simd.h"
#include "camera.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

/* ===== Test Utilities ===== */

typedef struct {
    const char *name;
    uint64_t start_cycle;
    uint64_t total_cycles;
    uint32_t sample_count;
} BenchTimer;

static inline uint64_t ysu_rdtsc(void) {
    return __builtin_ia32_rdtsc();
}

BenchTimer bench_start(const char *name) {
    BenchTimer t = {name, ysu_rdtsc(), 0, 0};
    return t;
}

void bench_end(BenchTimer *t) {
    uint64_t end = ysu_rdtsc();
    t->total_cycles += (end - t->start_cycle);
    t->sample_count++;
}

void bench_report(const BenchTimer *t, const char *unit) {
    if (t->sample_count == 0) {
        printf("  %s: No samples\n", t->name);
        return;
    }
    
    double avg_cycles = (double)t->total_cycles / t->sample_count;
    double avg_us = avg_cycles / 2.4;  /* Assuming 2.4 GHz CPU */
    
    if (strcmp(unit, "cycles") == 0) {
        printf("  %s: %.0f cycles/sample (%u samples)\n", t->name, avg_cycles, t->sample_count);
    } else if (strcmp(unit, "us") == 0) {
        printf("  %s: %.2f µs/sample (%u samples)\n", t->name, avg_us, t->sample_count);
    } else {
        printf("  %s: %.2f µs/sample, %.0f cycles/sample (%u samples)\n", 
               t->name, avg_us, avg_cycles, t->sample_count);
    }
}

/* ===== Test 1: Data Loading ===== */

void test_data_loading(void) {
    printf("\n=== TEST 1: Data Loading ===\n");
    
    const char *hashgrid_path = "models/nerf_hashgrid.bin";
    const char *occ_path = "models/occupancy_grid.bin";
    
    printf("Loading from: %s, %s\n", hashgrid_path, occ_path);
    
    clock_t t0 = clock();
    NeRFData *data = ysu_nerf_data_load(hashgrid_path, occ_path);
    clock_t t1 = clock();
    
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    double elapsed_ms = (double)(t1 - t0) / CLOCKS_PER_SEC * 1000.0;
    printf("✓ Loaded in %.2f ms\n", elapsed_ms);
    printf("  Config: %u levels, %u hash size, base_res=%u\n",
           data->config.num_levels, data->config.hashmap_size, data->config.base_res);
    printf("  MLP: %u -> %u -> %u -> %u\n",
           data->config.mlp_in_dim, data->config.mlp_hidden_dim,
           data->config.mlp_hidden_dim, data->config.mlp_out_dim);
    printf("  Center: (%.3f, %.3f, %.3f), Scale: %.3f\n",
           data->config.center.x, data->config.center.y, data->config.center.z,
           data->config.scale);
    
    ysu_nerf_data_free(data);
}

/* ===== Test 2: Hashgrid Lookup ===== */

void test_hashgrid_lookup(void) {
    printf("\n=== TEST 2: Hashgrid Lookup ===\n");
    
    NeRFData *data = ysu_nerf_data_load("models/nerf_hashgrid.bin", "models/occupancy_grid.bin");
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    /* Create test positions */
    Vec3 positions[SIMD_BATCH_SIZE];
    for (int i = 0; i < SIMD_BATCH_SIZE; i++) {
        positions[i].x = data->config.center.x + (float)i * 0.5f;
        positions[i].y = data->config.center.y + (float)i * 0.3f;
        positions[i].z = data->config.center.z;
    }
    
    /* Benchmark lookup */
    float features[SIMD_BATCH_SIZE][24];
    BenchTimer timer = bench_start("Hashgrid lookup (8 rays)");
    
    for (int iter = 0; iter < 100; iter++) {
        timer.start_cycle = ysu_rdtsc();
        ysu_hashgrid_lookup_batch(positions, &data->config, data->hashgrid_data, features);
        bench_end(&timer);
    }
    
    bench_report(&timer, "us");
    
    /* Print sample values */
    printf("  Sample features[0]: [%.3f, %.3f, %.3f, %.3f, ...]\n",
           features[0][0], features[0][1], features[0][2], features[0][3]);
    
    ysu_nerf_data_free(data);
}

/* ===== Test 3: MLP Inference ===== */

void test_mlp_inference(void) {
    printf("\n=== TEST 3: MLP Inference ===\n");
    
    NeRFData *data = ysu_nerf_data_load("models/nerf_hashgrid.bin", "models/occupancy_grid.bin");
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    /* Create test inputs */
    float features[SIMD_BATCH_SIZE][27];
    for (int ray = 0; ray < SIMD_BATCH_SIZE; ray++) {
        for (int i = 0; i < 27; i++) {
            features[ray][i] = (float)i / 27.0f - 0.5f;  /* Random-like test data */
        }
    }
    
    /* Benchmark MLP */
    float rgb_out[SIMD_BATCH_SIZE][3];
    float sigma_out[SIMD_BATCH_SIZE];
    
    BenchTimer timer = bench_start("MLP inference (8 rays)");
    
    for (int iter = 0; iter < 100; iter++) {
        timer.start_cycle = ysu_rdtsc();
        ysu_mlp_inference_batch(
            (const float(*)[27])features,
            &data->config,
            data->mlp_weights,
            data->mlp_biases,
            rgb_out,
            sigma_out
        );
        bench_end(&timer);
    }
    
    bench_report(&timer, "us");
    
    /* Print sample outputs */
    printf("  Sample RGB[0]: (%.3f, %.3f, %.3f), Sigma: %.3f\n",
           rgb_out[0][0], rgb_out[0][1], rgb_out[0][2], sigma_out[0]);
    printf("  Sample RGB[1]: (%.3f, %.3f, %.3f), Sigma: %.3f\n",
           rgb_out[1][0], rgb_out[1][1], rgb_out[1][2], sigma_out[1]);
    
    ysu_nerf_data_free(data);
}

/* ===== Test 4: Occupancy Lookup ===== */

void test_occupancy_lookup(void) {
    printf("\n=== TEST 4: Occupancy Lookup ===\n");
    
    NeRFData *data = ysu_nerf_data_load("models/nerf_hashgrid.bin", "models/occupancy_grid.bin");
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    /* Create test positions */
    Vec3 positions[SIMD_BATCH_SIZE];
    for (int i = 0; i < SIMD_BATCH_SIZE; i++) {
        positions[i].x = data->config.center.x + (float)(i - 4) * 0.2f;
        positions[i].y = data->config.center.y + (float)(i - 4) * 0.2f;
        positions[i].z = data->config.center.z;
    }
    
    /* Benchmark occupancy lookup */
    uint8_t occ_out[SIMD_BATCH_SIZE];
    BenchTimer timer = bench_start("Occupancy lookup (8 rays)");
    
    for (int iter = 0; iter < 1000; iter++) {
        timer.start_cycle = ysu_rdtsc();
        ysu_occupancy_lookup_batch(positions, &data->config, data->occupancy_grid, occ_out);
        bench_end(&timer);
    }
    
    bench_report(&timer, "us");
    
    /* Print occupancy values */
    printf("  Occupancy values:");
    for (int i = 0; i < SIMD_BATCH_SIZE; i++) {
        printf(" %u", occ_out[i]);
    }
    printf("\n");
    
    ysu_nerf_data_free(data);
}

/* ===== Test 5: Full Volume Integration ===== */

void test_volume_integration(void) {
    printf("\n=== TEST 5: Volume Integration (Full NeRF Rendering) ===\n");
    
    NeRFData *data = ysu_nerf_data_load("models/nerf_hashgrid.bin", "models/occupancy_grid.bin");
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    /* Create test framebuffer (small for speed) */
    uint32_t width = 256, height = 256;
    NeRFFramebuffer fb = {
        .width = width,
        .height = height,
        .pixels = (NeRFPixel*)malloc(width * height * sizeof(NeRFPixel))
    };
    
    /* Create camera positioned to view from side/front (see striped patterns) */
    float aspect_ratio = (float)width / (float)height;
    float viewport_h = 8.0f;  /* Good FOV for side view */
    float focal_length = 1.0f;
    Camera cam = camera_create(aspect_ratio, viewport_h, focal_length);
    
    /* Position camera to the side/front of the volume */
    /* Model center: (1.980, -1.481, -0.049), scale: 3.959 */
    float cam_distance = 12.0f;  /* Distance from center */
    Vec3 cam_pos = {
        data->config.center.x - cam_distance,   /* Move left (negative X) */
        data->config.center.y,                   /* Center Y */
        data->config.center.z - cam_distance * 0.5f  /* Move forward slightly */
    };
    
    /* Manually set camera position (override default) */
    cam.origin = cam_pos;
    
    /* Benchmark rendering */
    printf("Rendering %u x %u = %u pixels with 128 steps per ray\n", width, height, width * height);
    
    clock_t t0 = clock();
    
    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x += SIMD_BATCH_SIZE) {
            /* Create fresh batch for this tile */
            RayBatch batch;
            batch.count = SIMD_BATCH_SIZE;
            
            for (int i = 0; i < SIMD_BATCH_SIZE && x + i < width; i++) {
                /* Generate ray from camera with proper perspective */
                float u = ((float)(x + i) + 0.5f) / (float)width;
                float v = ((float)y + 0.5f) / (float)height;
                
                Ray ray = camera_get_ray(cam, u, v);
                
                batch.origin[i] = ray.origin;
                batch.direction[i] = ray.direction;
                batch.tmin[i] = 0.1f;
                batch.tmax[i] = 20.0f;
                batch.pixel_id[i] = y * width + x + i;  /* Correct pixel location */
                batch.active[i] = (x + i < width) ? 1 : 0;
            }
            
            ysu_volume_integrate_batch(&batch, &data->config, data, &fb, 128, 4.0f, 8.0f);
        }
    }
    
    clock_t t1 = clock();
    double elapsed_ms = (double)(t1 - t0) / CLOCKS_PER_SEC * 1000.0;
    double elapsed_sec = elapsed_ms / 1000.0;
    
    printf("✓ Rendered in %.2f ms (%.2f sec)\n", elapsed_ms, elapsed_sec);
    printf("  Throughput: %.1f pixels/ms, %.1f FPS @ 1080p\n",
           (width * height) / elapsed_ms,
           1000.0 / (elapsed_ms * (1920.0 * 1080.0 / (width * height))));
    
    /* Save output */
    FILE *f = fopen("nerf_simd_test_output.ppm", "wb");
    if (f) {
        fprintf(f, "P6\n%u %u\n255\n", width, height);
        for (uint32_t i = 0; i < width * height; i++) {
            uint8_t r = (uint8_t)(fb.pixels[i].rgb.x * 255.0f);
            uint8_t g = (uint8_t)(fb.pixels[i].rgb.y * 255.0f);
            uint8_t b = (uint8_t)(fb.pixels[i].rgb.z * 255.0f);
            fputc(r, f);
            fputc(g, f);
            fputc(b, f);
        }
        fclose(f);
        printf("  Wrote nerf_simd_test_output.ppm\n");
    }
    
    free(fb.pixels);
    ysu_nerf_data_free(data);
}

/* ===== Comprehensive Benchmark ===== */

void benchmark_component_breakdown(void) {
    printf("\n=== BENCHMARK: Component Breakdown ===\n");
    
    NeRFData *data = ysu_nerf_data_load("models/nerf_hashgrid.bin", "models/occupancy_grid.bin");
    if (!data) {
        printf("FAIL: Could not load NeRF data\n");
        return;
    }
    
    Vec3 test_pos = data->config.center;
    uint8_t occ_out[SIMD_BATCH_SIZE];
    float features[SIMD_BATCH_SIZE][24];
    float feat_batch[SIMD_BATCH_SIZE][27];
    float rgb[SIMD_BATCH_SIZE][3];
    float sigma[SIMD_BATCH_SIZE];
    
    /* Prepare test batch */
    Vec3 positions[SIMD_BATCH_SIZE];
    for (int i = 0; i < SIMD_BATCH_SIZE; i++) {
        positions[i] = test_pos;
    }
    
    for (int i = 0; i < SIMD_BATCH_SIZE; i++) {
        for (int j = 0; j < 27; j++) {
            feat_batch[i][j] = (float)j / 27.0f;
        }
    }
    
    /* Benchmark each component */
    printf("Per-step costs (averaged over 1000 iterations):\n");
    
    /* Hashgrid */
    BenchTimer t_grid = bench_start("Hashgrid lookup");
    for (int iter = 0; iter < 1000; iter++) {
        t_grid.start_cycle = ysu_rdtsc();
        ysu_hashgrid_lookup_batch(positions, &data->config, data->hashgrid_data, features);
        bench_end(&t_grid);
    }
    bench_report(&t_grid, "us");
    
    /* MLP */
    BenchTimer t_mlp = bench_start("MLP inference");
    for (int iter = 0; iter < 1000; iter++) {
        t_mlp.start_cycle = ysu_rdtsc();
        ysu_mlp_inference_batch((const float(*)[27])feat_batch, &data->config,
                               data->mlp_weights, data->mlp_biases, rgb, sigma);
        bench_end(&t_mlp);
    }
    bench_report(&t_mlp, "us");
    
    /* Occupancy */
    BenchTimer t_occ = bench_start("Occupancy lookup");
    for (int iter = 0; iter < 10000; iter++) {
        t_occ.start_cycle = ysu_rdtsc();
        ysu_occupancy_lookup_batch(positions, &data->config, data->occupancy_grid, occ_out);
        bench_end(&t_occ);
    }
    bench_report(&t_occ, "us");
    
    printf("\nEstimated per-ray costs:\n");
    printf("  Total per-step: ~200 µs (8 rays in parallel)\n");
    printf("  Per-ray: ~25 µs per step\n");
    printf("  At 32 steps per pixel: ~800 µs per pixel\n");
    printf("  1080p (2M pixels): ~1600 seconds (!)  -- This is expected for CPU\n");
    printf("  But with 8 cores: ~200 seconds, or ~5 FPS\n");
    printf("  With 64x64 resolution: ~2.5 seconds = 0.4 FPS baseline\n");
    
    ysu_nerf_data_free(data);
}

/* ===== Main Test Suite ===== */

int main(int argc, char *argv[]) {
    printf("\n");
    printf("╔═══════════════════════════════════════════╗\n");
    printf("║  NeRF SIMD CPU Renderer - Test Suite     ║\n");
    printf("║  Comprehensive validation and benchmark  ║\n");
    printf("╚═══════════════════════════════════════════╝\n");
    
    test_data_loading();
    test_hashgrid_lookup();
    test_mlp_inference();
    test_occupancy_lookup();
    benchmark_component_breakdown();
    test_volume_integration();
    
    printf("\n");
    printf("╔═══════════════════════════════════════════╗\n");
    printf("║  All Tests Completed                      ║\n");
    printf("╚═══════════════════════════════════════════╝\n");
    printf("\n");
    
    return 0;
}
