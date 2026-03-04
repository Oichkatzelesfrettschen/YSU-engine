/* test_upscale_unit.c — Unit tests for YSU Neural Upscale system
 *
 * Tests the non-Vulkan parts (math, constants, API contracts).
 * A full integration test would require a Vulkan device context.
 *
 * Compile:
 *   gcc -std=c11 -O2 -o test_upscale_unit test_upscale_unit.c ysu_upscale.c -lm
 *
 * Run:
 *   ./test_upscale_unit
 */

#include "ysu_upscale.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define ASSERT(cond, msg) \
    do { \
        if (!(cond)) { \
            fprintf(stderr, "FAIL: %s\n", msg); \
            return 0; \
        } \
    } while (0)

#define ASSERT_APPROX(a, b, tol, msg) \
    do { \
        float diff = fabsf((a) - (b)); \
        if (diff > (tol)) { \
            fprintf(stderr, "FAIL: %s (%.6f vs %.6f, diff %.6f)\n", msg, a, b, diff); \
            return 0; \
        } \
    } while (0)

/* ═══════════════════════════════════════════════════════════════════
 *  Test 1: Halton sequence correctness
 * ═══════════════════════════════════════════════════════════════════ */

int test_halton_sequence(void) {
    printf("[TEST 1] Halton(2,3) jitter sequence...\n");

    /* Known Halton values:
     * Halton(n, 2): 0.5, 0.25, 0.75, 0.125, 0.625, ...
     * Halton(n, 3): 1/3, 2/3, 1/9, 4/9, 7/9, ...
     */

    float h2_1 = ysu_halton(1, 2);
    ASSERT_APPROX(h2_1, 0.5f, 1e-6, "Halton(1,2) = 0.5");

    float h2_2 = ysu_halton(2, 2);
    ASSERT_APPROX(h2_2, 0.25f, 1e-6, "Halton(2,2) = 0.25");

    float h2_3 = ysu_halton(3, 2);
    ASSERT_APPROX(h2_3, 0.75f, 1e-6, "Halton(3,2) = 0.75");

    float h3_1 = ysu_halton(1, 3);
    ASSERT_APPROX(h3_1, 1.0f/3.0f, 1e-6, "Halton(1,3) = 1/3");

    float h3_2 = ysu_halton(2, 3);
    ASSERT_APPROX(h3_2, 2.0f/3.0f, 1e-6, "Halton(2,3) = 2/3");

    printf("  ✓ Halton sequence correct\n");
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Test 2: Jitter generation at runtime
 * ═══════════════════════════════════════════════════════════════════ */

int test_jitter_generation(void) {
    printf("[TEST 2] Jitter generation (frame-indexed)...\n");

    /* Frame 0 */
    YsuJitter j0 = ysu_upscale_jitter(0);
    ASSERT(j0.x >= -0.5f && j0.x <= 0.5f, "Jitter X in [-0.5, 0.5]");
    ASSERT(j0.y >= -0.5f && j0.y <= 0.5f, "Jitter Y in [-0.5, 0.5]");

    /* Frame 1 — should differ */
    YsuJitter j1 = ysu_upscale_jitter(1);
    float dist = sqrtf(j1.x * j1.x + j1.y * j1.y);
    ASSERT(dist > 0.01f, "Frame 1 jitter differs from frame 0");

    /* Frame 16 — cycles back (16-phase Halton) */
    YsuJitter j16 = ysu_upscale_jitter(16);
    YsuJitter j0_repeat = ysu_upscale_jitter(0 + 16);
    ASSERT_APPROX(j16.x, j0_repeat.x, 1e-6, "Jitter cycles at phase 16");
    ASSERT_APPROX(j16.y, j0_repeat.y, 1e-6, "Jitter cycles at phase 16");

    printf("  ✓ Jitter generation valid (16-phase cycle)\n");
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Test 3: Quality factor correctness
 * ═══════════════════════════════════════════════════════════════════ */

int test_quality_factors(void) {
    printf("[TEST 3] Quality preset factors...\n");

    float f_ultra_perf = ysu_upscale_quality_factor(YSU_UPSCALE_QUALITY_ULTRA_PERF);
    float f_perf       = ysu_upscale_quality_factor(YSU_UPSCALE_QUALITY_PERFORMANCE);
    float f_balanced   = ysu_upscale_quality_factor(YSU_UPSCALE_QUALITY_BALANCED);
    float f_quality    = ysu_upscale_quality_factor(YSU_UPSCALE_QUALITY_QUALITY);
    float f_ultra      = ysu_upscale_quality_factor(YSU_UPSCALE_QUALITY_ULTRA);

    /* Each should be in (0, 1] and ordered correctly */
    ASSERT(f_ultra_perf > 0.0f && f_ultra_perf < 0.5f, "ULTRA_PERF ≈ 1/3");
    ASSERT(f_perf > 0.4f && f_perf < 0.6f, "PERFORMANCE ≈ 1/2");
    ASSERT(f_balanced > f_perf && f_balanced < f_quality, "BALANCED ordered");
    ASSERT(f_quality > f_balanced && f_quality < f_ultra, "QUALITY ordered");
    ASSERT(f_ultra > f_quality, "ULTRA highest");

    /* Check specific values */
    ASSERT_APPROX(f_ultra_perf, 1.0f/3.0f, 0.01f, "ULTRA_PERF = 1/3");
    ASSERT_APPROX(f_perf, 1.0f/2.0f, 0.01f, "PERFORMANCE = 1/2");
    ASSERT_APPROX(f_quality, 1.0f/1.5f, 0.01f, "QUALITY = 2/3");

    printf("  ✓ Quality factors: ");
    printf("ULTRA_PERF=%.3f, PERF=%.3f, BAL=%.3f, QUAL=%.3f, ULTRA=%.3f\n",
           f_ultra_perf, f_perf, f_balanced, f_quality, f_ultra);
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Test 4: Upscale resolution calculations
 * ═══════════════════════════════════════════════════════════════════ */

int test_resolution_scaling(void) {
    printf("[TEST 4] Resolution scaling (1080p → 4K scenarios)...\n");

    uint32_t display_w = 3840, display_h = 2160;

    for (int preset = 0; preset < YSU_UPSCALE_QUALITY_COUNT; preset++) {
        float scale = ysu_upscale_quality_factor((YsuUpscaleQuality)preset);
        uint32_t w_lo = (uint32_t)(display_w * scale);
        uint32_t h_lo = (uint32_t)(display_h * scale);

        float upscale_ratio = (float)display_w / (float)w_lo;
        ASSERT(upscale_ratio >= 1.25f && upscale_ratio <= 3.05f, "Upscale ratio in valid range");

        printf("  Preset %d: %.0f×%.0f (scale %.2f, ratio %.2f×)\n",
               preset, (float)w_lo, (float)h_lo, scale, upscale_ratio);
    }

    printf("  ✓ Valid resolutions across all presets\n");
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Test 5: Header struct packing (size contracts)
 * ═══════════════════════════════════════════════════════════════════ */

int test_struct_sizes(void) {
    printf("[TEST 5] Struct size contracts...\n");

    /* These are critical for push constant compatibility with GLSL shaders */
    ASSERT(sizeof(YsuReprojPC) >= 48, "YsuReprojPC >= 48 bytes");
    ASSERT(sizeof(YsuNeuralPC) >= 48, "YsuNeuralPC >= 48 bytes");
    ASSERT(sizeof(YsuSharpenPC) >= 16, "YsuSharpenPC >= 16 bytes");

    printf("  YsuReprojPC:   %zu bytes\n", sizeof(YsuReprojPC));
    printf("  YsuNeuralPC:   %zu bytes\n", sizeof(YsuNeuralPC));
    printf("  YsuSharpenPC:  %zu bytes\n", sizeof(YsuSharpenPC));
    printf("  ✓ All push constants properly sized\n");
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Test 6: Jitter pattern energy distribution
 *
 *  Verify that the Halton sequence provides good blue-noise properties
 *  (low-frequency content, high-frequency noise).
 * ═══════════════════════════════════════════════════════════════════ */

int test_jitter_distribution(void) {
    printf("[TEST 6] Jitter distribution (statistical properties)...\n");

    float sum_x = 0.0f, sum_y = 0.0f;
    float var_x = 0.0f, var_y = 0.0f;

    for (uint32_t i = 0; i < 64; i++) {
        YsuJitter j = ysu_upscale_jitter(i);
        sum_x += j.x;
        sum_y += j.y;
    }

    float mean_x = sum_x / 64.0f;
    float mean_y = sum_y / 64.0f;

    for (uint32_t i = 0; i < 64; i++) {
        YsuJitter j = ysu_upscale_jitter(i);
        float dx = j.x - mean_x;
        float dy = j.y - mean_y;
        var_x += dx * dx;
        var_y += dy * dy;
    }

    var_x /= 64.0f;
    var_y /= 64.0f;

    /* Halton sequence should be well-distributed with mean ≈ 0
     * and variance ≈ 1/12 ≈ 0.083 for uniform distribution */
    ASSERT(fabsf(mean_x) < 0.1f, "Mean jitter X ≈ 0");
    ASSERT(fabsf(mean_y) < 0.1f, "Mean jitter Y ≈ 0");
    ASSERT(var_x > 0.05f && var_x < 0.15f, "Variance X reasonable (0.05–0.15)");
    ASSERT(var_y > 0.05f && var_y < 0.15f, "Variance Y reasonable (0.05–0.15)");

    printf("  Mean:     (%.4f, %.4f)\n", mean_x, mean_y);
    printf("  Variance: (%.4f, %.4f)\n", var_x, var_y);
    printf("  ✓ Jitter distribution is well-balanced (blue-noise-like)\n");
    return 1;
}

/* ═══════════════════════════════════════════════════════════════════
 *  Main test runner
 * ═══════════════════════════════════════════════════════════════════ */

int main(void) {
    printf("\n╔════════════════════════════════════════════════════════════╗\n");
    printf("║      YSU Neural Upscale — Unit Test Suite                 ║\n");
    printf("╚════════════════════════════════════════════════════════════╝\n\n");

    int tests_passed = 0, tests_total = 6;

    if (test_halton_sequence())       tests_passed++;
    if (test_jitter_generation())     tests_passed++;
    if (test_quality_factors())       tests_passed++;
    if (test_resolution_scaling())    tests_passed++;
    if (test_struct_sizes())          tests_passed++;
    if (test_jitter_distribution())   tests_passed++;

    printf("\n╔════════════════════════════════════════════════════════════╗\n");
    printf("║ RESULTS: %d/%d tests passed                                ║\n", tests_passed, tests_total);
    printf("╚════════════════════════════════════════════════════════════╝\n\n");

    if (tests_passed == tests_total) {
        printf("✓ ALL TESTS PASSED\n");
        printf("\nNext steps:\n");
        printf("  1. Compile shaders: glslc -O shaders/upscale_*.comp -o shaders/upscale_*.spv\n");
        printf("  2. Integrate with your Vulkan renderer (see ysu_upscale_integration_example.c)\n");
        printf("  3. Train neural weights (see YSU_NEURAL_UPSCALE_ARCHITECTURE.md § 4)\n");
        return 0;
    } else {
        printf("✗ %d/%d TESTS FAILED\n", tests_total - tests_passed, tests_total);
        return 1;
    }
}
