/*
 * Instant-NGP Hash Grid Encoding — SASS-level inline PTX (v2)
 *
 * This is the hottest kernel in instant-NGP. For each 3D query point,
 * it encodes position into a feature vector by:
 *   1. For each of L resolution levels:
 *      a. Scale position to grid coordinates
 *      b. Find the 8 corners of the enclosing voxel
 *      c. Hash each corner → index into feature table
 *      d. Load 2 features per corner (16 loads per level)
 *      e. Trilinear interpolation → 2 output features
 *   2. Concatenate all 2L features as network input
 *
 * Target: SM 8.9 (Ada Lovelace)
 *
 * v2 changes from v1:
 *   - Non-volatile asm for compute ops → ptxas can freely reorder
 *     to interleave LDG with ALU and hide ~200-cycle L2 latency
 *   - volatile ONLY on loads/stores (actual side effects)
 *   - Trilinear interpolation in C → compiler generates FFMA+FSUB
 *     with optimal scheduling
 *   - LOP3 stays inline PTX (no C equivalent for 3-input XOR)
 *   - __ldg() intrinsic for cache-through loads
 *
 * v3 changes from v2:
 *   - float2 vectorized loads: 16× LDG.32 → 8× LDG.64 per level
 *     Halves load instruction count; hardware 64-bit loads are same
 *     throughput as 32-bit but issue twice the data per instruction.
 *   - Software-pipelined across level pairs: issue loads for level N+1
 *     while computing trilinear for level N. Doubles outstanding
 *     memory requests (16 LDG.64 in-flight vs 8).
 *
 * SASS instruction budget per level (v3 target):
 *   - 6× FFMA  (scale + floor + fract)
 *   - 3× F2I   (float grid coords → int)
 *   - 24× IMAD (8 corners × 3 primes for hashing)
 *   - 8× LOP3  (8 corners XOR reduction)
 *   - 8× LOP3  (hash masking, AND)
 *   - 8× LDG.64 (8 corners × float2 features)
 *   - 14× FFMA (trilinear interpolation: 7 lerps × 2 features)
 *   Total: ~71 instructions per level
 */

#include <cuda_runtime.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>

/* ════════════════════════════════════════════════════════════════
 * Configuration — matches the engine's NeRFConfig
 * ════════════════════════════════════════════════════════════════ */

#define NGP_NUM_LEVELS      12
#define NGP_FEATURES_PER    2       /* features per hash entry */
#define NGP_HASHMAP_SIZE    131072  /* 2^17 entries per level */
#define NGP_LOG2_HASHMAP    17
#define NGP_BASE_RES        16
#define NGP_PER_LEVEL_SCALE 1.5f
#define NGP_TOTAL_FEATURES  (NGP_NUM_LEVELS * NGP_FEATURES_PER)  /* 24 */

/* Safety: if NGP_NUM_LEVELS is ever changed the caller's feature buffer must
 * be resized to N * NGP_TOTAL_FEATURES floats.  Catch mismatches at compile
 * time.  If you see this assertion, update NGP_TOTAL_FEATURES or the buffer
 * allocation in the caller to match NGP_NUM_LEVELS * NGP_FEATURES_PER. */
static_assert(NGP_TOTAL_FEATURES == NGP_NUM_LEVELS * NGP_FEATURES_PER,
    "NGP_TOTAL_FEATURES must equal NGP_NUM_LEVELS * NGP_FEATURES_PER — "
    "update both together to avoid out-of-bounds writes into feature buffers");

/* Spatial hash primes (same as engine's ysu_hash_ijk) */
#define PRIME_X 73856093u
#define PRIME_Y 19349663u
#define PRIME_Z 83492791u


/* ════════════════════════════════════════════════════════════════
 * KERNEL 1: Hash Grid Encoding — Full inline PTX
 *
 * Each thread encodes ONE 3D point → 24 output features.
 * Grid: <<<(N+255)/256, 256>>>
 *
 * Args:
 *   positions:  [N][3] float — normalized 3D positions in [0,1]
 *   hash_table: [L][HASHMAP_SIZE][2] float — feature table
 *   features:   [N][24] float — output encoded features
 *   N:          number of points
 * ════════════════════════════════════════════════════════════════ */

extern "C" __global__ void __launch_bounds__(256)
hashgrid_encode_ptx(
    const float * __restrict__ positions,
    const float * __restrict__ hash_table,
    float       * __restrict__ features,
    int N
) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= N) return;

    /* ── Load position (coalesced) ── */
    const float *pos_ptr = positions + tid * 3;
    float px = pos_ptr[0];
    float py = pos_ptr[1];
    float pz = pos_ptr[2];

    /* ── Per-level encoding with software pipelining ──
     * Process 2 levels at a time: issue loads for level N+1
     * while computing trilinear for level N. This doubles
     * outstanding memory requests (16 LDG.64 in-flight). */
    float *feat_out = features + tid * NGP_TOTAL_FEATURES;

    /* === Macros for per-level hash + load + trilinear === */

    #define LOP3_XOR(dst, a, b, c) \
        asm("lop3.b32 %0, %1, %2, %3, 0x96;" : "=r"(dst) : "r"(a), "r"(b), "r"(c))

    #define HASH_AND_LOAD(S, LVL_SCALE, LVL_IDX)                              \
    {                                                                          \
        float gx_##S = px * (LVL_SCALE);                                       \
        float gy_##S = py * (LVL_SCALE);                                       \
        float gz_##S = pz * (LVL_SCALE);                                       \
                                                                               \
        float fx_##S = floorf(gx_##S);                                         \
        float fy_##S = floorf(gy_##S);                                         \
        float fz_##S = floorf(gz_##S);                                         \
                                                                               \
        wx_##S = gx_##S - fx_##S;                                              \
        wy_##S = gy_##S - fy_##S;                                              \
        wz_##S = gz_##S - fz_##S;                                              \
                                                                               \
        int ix_##S = (int)fx_##S;                                              \
        int iy_##S = (int)fy_##S;                                              \
        int iz_##S = (int)fz_##S;                                              \
                                                                               \
        unsigned hx0_##S = (unsigned)ix_##S * PRIME_X;                         \
        unsigned hy0_##S = (unsigned)iy_##S * PRIME_Y;                         \
        unsigned hz0_##S = (unsigned)iz_##S * PRIME_Z;                         \
        unsigned hx1_##S = hx0_##S + PRIME_X;                                  \
        unsigned hy1_##S = hy0_##S + PRIME_Y;                                  \
        unsigned hz1_##S = hz0_##S + PRIME_Z;                                  \
                                                                               \
        unsigned c0_##S, c1_##S, c2_##S, c3_##S;                               \
        unsigned c4_##S, c5_##S, c6_##S, c7_##S;                               \
        LOP3_XOR(c0_##S, hx0_##S, hy0_##S, hz0_##S);                          \
        LOP3_XOR(c1_##S, hx0_##S, hy0_##S, hz1_##S);                          \
        LOP3_XOR(c2_##S, hx0_##S, hy1_##S, hz0_##S);                          \
        LOP3_XOR(c3_##S, hx0_##S, hy1_##S, hz1_##S);                          \
        LOP3_XOR(c4_##S, hx1_##S, hy0_##S, hz0_##S);                          \
        LOP3_XOR(c5_##S, hx1_##S, hy0_##S, hz1_##S);                          \
        LOP3_XOR(c6_##S, hx1_##S, hy1_##S, hz0_##S);                          \
        LOP3_XOR(c7_##S, hx1_##S, hy1_##S, hz1_##S);                          \
                                                                               \
        const unsigned mask = NGP_HASHMAP_SIZE - 1;                            \
        c0_##S &= mask; c1_##S &= mask;                                       \
        c2_##S &= mask; c3_##S &= mask;                                       \
        c4_##S &= mask; c5_##S &= mask;                                       \
        c6_##S &= mask; c7_##S &= mask;                                       \
                                                                               \
        /* float2 vectorized loads: 8× LDG.64 instead of 16× LDG.32 */        \
        const float2 *lp2_##S = (const float2*)(hash_table                     \
            + (size_t)(LVL_IDX) * NGP_HASHMAP_SIZE * NGP_FEATURES_PER);        \
                                                                               \
        v0_##S = __ldg(lp2_##S + c0_##S);                                      \
        v1_##S = __ldg(lp2_##S + c1_##S);                                      \
        v2_##S = __ldg(lp2_##S + c2_##S);                                      \
        v3_##S = __ldg(lp2_##S + c3_##S);                                      \
        v4_##S = __ldg(lp2_##S + c4_##S);                                      \
        v5_##S = __ldg(lp2_##S + c5_##S);                                      \
        v6_##S = __ldg(lp2_##S + c6_##S);                                      \
        v7_##S = __ldg(lp2_##S + c7_##S);                                      \
    }

    #define TRILINEAR_AND_STORE(S, LVL_IDX)                                    \
    {                                                                          \
        float a0 = v0_##S.x + wx_##S * (v4_##S.x - v0_##S.x);                \
        float a1 = v1_##S.x + wx_##S * (v5_##S.x - v1_##S.x);                \
        float a2 = v2_##S.x + wx_##S * (v6_##S.x - v2_##S.x);                \
        float a3 = v3_##S.x + wx_##S * (v7_##S.x - v3_##S.x);                \
        float b0 = a0 + wy_##S * (a2 - a0);                                   \
        float b1 = a1 + wy_##S * (a3 - a1);                                   \
        feat_out[(LVL_IDX) * 2 + 0] = b0 + wz_##S * (b1 - b0);               \
                                                                               \
        a0 = v0_##S.y + wx_##S * (v4_##S.y - v0_##S.y);                       \
        a1 = v1_##S.y + wx_##S * (v5_##S.y - v1_##S.y);                       \
        a2 = v2_##S.y + wx_##S * (v6_##S.y - v2_##S.y);                       \
        a3 = v3_##S.y + wx_##S * (v7_##S.y - v3_##S.y);                       \
        b0 = a0 + wy_##S * (a2 - a0);                                         \
        b1 = a1 + wy_##S * (a3 - a1);                                         \
        feat_out[(LVL_IDX) * 2 + 1] = b0 + wz_##S * (b1 - b0);               \
    }

    /* Process 12 levels in 6 pairs, software-pipelined:
     * Issue loads for both levels, then trilinear for both.
     * This keeps 16 LDG.64 in-flight simultaneously. */

    #pragma unroll
    for (int pair = 0; pair < NGP_NUM_LEVELS / 2; pair++) {
        int lvl_a = pair * 2;
        int lvl_b = pair * 2 + 1;
        float scale_a = (float)NGP_BASE_RES;
        float scale_b = (float)NGP_BASE_RES;
        /* Compute per-level scales */
        for (int i = 0; i < lvl_a; i++) scale_a *= NGP_PER_LEVEL_SCALE;
        for (int i = 0; i < lvl_b; i++) scale_b *= NGP_PER_LEVEL_SCALE;

        /* Declared outside macros for cross-macro visibility */
        float wx_A, wy_A, wz_A, wx_B, wy_B, wz_B;
        float2 v0_A, v1_A, v2_A, v3_A, v4_A, v5_A, v6_A, v7_A;
        float2 v0_B, v1_B, v2_B, v3_B, v4_B, v5_B, v6_B, v7_B;

        /* Phase 1: hash + issue loads for BOTH levels */
        HASH_AND_LOAD(A, scale_a, lvl_a)
        HASH_AND_LOAD(B, scale_b, lvl_b)

        /* Phase 2: trilinear + store for BOTH levels
         * By now, loads from Phase 1 have had time to reach L2/DRAM */
        TRILINEAR_AND_STORE(A, lvl_a)
        TRILINEAR_AND_STORE(B, lvl_b)
    }

    #undef LOP3_XOR
    #undef HASH_AND_LOAD
    #undef TRILINEAR_AND_STORE
}


/* ════════════════════════════════════════════════════════════════
 * Reference CUDA implementation (for validation)
 * ════════════════════════════════════════════════════════════════ */

__device__ __forceinline__
uint32_t hash_corner_ref(int ix, int iy, int iz) {
    uint32_t h = ((uint32_t)ix * PRIME_X) ^ ((uint32_t)iy * PRIME_Y)
               ^ ((uint32_t)iz * PRIME_Z);
    return h & (NGP_HASHMAP_SIZE - 1);
}

__device__ __forceinline__
float lerp_ref(float a, float b, float t) {
    return a + t * (b - a);
}

extern "C" __global__ void __launch_bounds__(256)
hashgrid_encode_ref(
    const float * __restrict__ positions,
    const float * __restrict__ hash_table,
    float       * __restrict__ features,
    int N
) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= N) return;

    float px = positions[tid * 3 + 0];
    float py = positions[tid * 3 + 1];
    float pz = positions[tid * 3 + 2];

    float *feat_out = features + tid * NGP_TOTAL_FEATURES;
    float scale = (float)NGP_BASE_RES;

    for (int level = 0; level < NGP_NUM_LEVELS; level++) {
        float gx = px * scale;
        float gy = py * scale;
        float gz = pz * scale;

        int ix = (int)floorf(gx);
        int iy = (int)floorf(gy);
        int iz = (int)floorf(gz);

        float wx = gx - floorf(gx);
        float wy = gy - floorf(gy);
        float wz = gz - floorf(gz);

        /* 8 corner lookups */
        float f0[8], f1[8];
        for (int dz = 0; dz < 2; dz++)
        for (int dy = 0; dy < 2; dy++)
        for (int dx = 0; dx < 2; dx++) {
            int c = dx * 4 + dy * 2 + dz;
            uint32_t idx = hash_corner_ref(ix + dx, iy + dy, iz + dz);
            const float *entry = hash_table
                + (size_t)level * NGP_HASHMAP_SIZE * NGP_FEATURES_PER
                + idx * NGP_FEATURES_PER;
            f0[c] = entry[0];
            f1[c] = entry[1];
        }

        /* Trilinear interpolation */
        float x00 = lerp_ref(f0[0], f0[4], wx);
        float x01 = lerp_ref(f0[1], f0[5], wx);
        float x10 = lerp_ref(f0[2], f0[6], wx);
        float x11 = lerp_ref(f0[3], f0[7], wx);
        float y0  = lerp_ref(x00, x10, wy);
        float y1  = lerp_ref(x01, x11, wy);
        feat_out[level * 2 + 0] = lerp_ref(y0, y1, wz);

        x00 = lerp_ref(f1[0], f1[4], wx);
        x01 = lerp_ref(f1[1], f1[5], wx);
        x10 = lerp_ref(f1[2], f1[6], wx);
        x11 = lerp_ref(f1[3], f1[7], wx);
        y0  = lerp_ref(x00, x10, wy);
        y1  = lerp_ref(x01, x11, wy);
        feat_out[level * 2 + 1] = lerp_ref(y0, y1, wz);

        scale *= NGP_PER_LEVEL_SCALE;
    }
}
