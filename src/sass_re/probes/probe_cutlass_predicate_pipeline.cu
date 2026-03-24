/*
 * SASS RE Probe: CUTLASS-like predicate-banked tensor pipeline
 *
 * Goal: make ptxas preserve a larger set of warp-uniform tail predicates
 * across a software-pipelined cp.async + HMMA mainloop, then reuse them late
 * enough that banked predicate save/restore or uniform predicate logic becomes
 * attractive.
 */

#include <cuda_runtime.h>
#include <stdint.h>

static __device__ __forceinline__ unsigned cutlass_smem_addr(unsigned char *ptr) {
    return static_cast<unsigned>(__cvta_generic_to_shared(ptr));
}

extern "C" __global__ void __launch_bounds__(32)
probe_cutlass_predicate_pipeline(float *out,
                                 const float *a_in,
                                 const float *b_in,
                                 const unsigned char *src,
                                 int tiles,
                                 int stride,
                                 int tail_mask,
                                 int stage_mask) {
    __shared__ __align__(16) unsigned char smem[2][64];
    int lane = threadIdx.x;

    unsigned a0 = 0, a1 = 0, a2 = 0, a3 = 0;
    unsigned b0 = 0, b1 = 0;
    float d0 = 0.0f, d1 = 0.0f, d2 = 0.0f, d3 = 0.0f;

    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(a0) : "f"(a_in[lane + 0 * 32]));
    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(a1) : "f"(a_in[lane + 1 * 32]));
    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(a2) : "f"(a_in[lane + 2 * 32]));
    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(a3) : "f"(a_in[lane + 3 * 32]));
    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(b0) : "f"(b_in[lane + 0 * 32]));
    asm volatile("cvt.rna.tf32.f32 %0, %1;" : "=r"(b1) : "f"(b_in[lane + 1 * 32]));

    bool t0 = (tail_mask & 0x01) != 0;
    bool t1 = (tail_mask & 0x02) != 0;
    bool t2 = (tail_mask & 0x04) != 0;
    bool t3 = (tail_mask & 0x08) != 0;
    bool t4 = (tail_mask & 0x10) != 0;
    bool t5 = (tail_mask & 0x20) != 0;
    bool t6 = (tail_mask & 0x40) != 0;

    bool s0 = (stage_mask & 0x01) != 0;
    bool s1 = (stage_mask & 0x02) != 0;
    bool s2 = (stage_mask & 0x04) != 0;
    bool s3 = (stage_mask & 0x08) != 0;

    const unsigned base0 = cutlass_smem_addr(smem[0]);
    const unsigned base1 = cutlass_smem_addr(smem[1]);

    if (tiles > 0) {
        asm volatile("cp.async.cg.shared.global.L2::128B [%0], [%1], 16;"
                     :: "r"(base0), "l"(src));
        if (tiles > 1) {
            asm volatile("cp.async.cg.shared.global.L2::128B [%0], [%1], 16, 8;"
                         :: "r"(base1), "l"(src + stride));
        }
        asm volatile("cp.async.commit_group;");
    }

    #pragma unroll 1
    for (int t = 0; t < tiles; ++t) {
        int stage = t & 1;
        int next_stage = stage ^ 1;
        unsigned cur_dst = stage ? base1 : base0;
        unsigned nxt_dst = next_stage ? base1 : base0;
        const unsigned char *gptr = src + t * stride;
        const unsigned char *nxt_gptr = gptr + stride;

        bool stage_wrap = ((t & 3) == 3);
        bool pred_a = t0 || (stage_wrap && s0);
        bool pred_b = t1 || ((!stage_wrap) && s1);
        bool pred_c = t2 ^ s2;
        bool pred_d = t3 || s3;
        bool pred_e = t4 && !stage_wrap;
        bool pred_f = t5 || ((t & 1) == 0);
        bool pred_g = t6 || ((t & 2) != 0);

        asm volatile("cp.async.wait_group 0;");

        if (t + 1 < tiles) {
            if (pred_a || pred_c) {
                asm volatile("cp.async.cg.shared.global.L2::128B [%0], [%1], 16;"
                             :: "r"(nxt_dst), "l"(nxt_gptr));
            } else {
                asm volatile("cp.async.cg.shared.global.L2::128B [%0], [%1], 16, 8;"
                             :: "r"(nxt_dst), "l"(nxt_gptr));
            }
            asm volatile("cp.async.commit_group;");
        }

        if (pred_b || pred_d) {
            asm volatile(
                "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
                "{%0, %1, %2, %3}, "
                "{%4, %5, %6, %7}, "
                "{%8, %9}, "
                "{%0, %1, %2, %3};"
                : "+f"(d0), "+f"(d1), "+f"(d2), "+f"(d3)
                : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(b0), "r"(b1));
        }

        if (pred_e || pred_f) {
            asm volatile(
                "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
                "{%0, %1, %2, %3}, "
                "{%4, %5, %6, %7}, "
                "{%8, %9}, "
                "{%0, %1, %2, %3};"
                : "+f"(d0), "+f"(d1), "+f"(d2), "+f"(d3)
                : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(b0), "r"(b1));
        }

        if (pred_g) {
            asm volatile(
                "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
                "{%0, %1, %2, %3}, "
                "{%4, %5, %6, %7}, "
                "{%8, %9}, "
                "{%0, %1, %2, %3};"
                : "+f"(d0), "+f"(d1), "+f"(d2), "+f"(d3)
                : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(b0), "r"(b1));
        }

        if (pred_a && pred_d) d0 += (float)smem[stage][0];
        if (pred_b && pred_e) d1 += (float)smem[stage][1];
        if (pred_c && pred_f) d2 += (float)smem[next_stage][2];
        if (pred_g && !pred_a) d3 += (float)smem[next_stage][3];

        // Late reuse of the original warp-uniform tail predicates.
        if (t0 && t4) d0 += 1.0f;
        if (t1 && t5) d1 += 2.0f;
        if (t2 && t6) d2 += 3.0f;
        if (t3 && !t0) d3 += 4.0f;

        // Keep the predicates and accumulators live across the loop body.
        asm volatile("" :: "f"(d0), "f"(d1), "f"(d2), "f"(d3));
    }

    out[lane + 0 * 32] = d0;
    out[lane + 1 * 32] = d1;
    out[lane + 2 * 32] = d2;
    out[lane + 3 * 32] = d3;
}
