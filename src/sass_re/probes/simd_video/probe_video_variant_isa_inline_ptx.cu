#include <stdint.h>

static __device__ __forceinline__ int video_variant_idx(int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    return i < n ? i : -1;
}

#define VIDEO_VARIANT(name, ptx, cinit) \
extern "C" __global__ void __launch_bounds__(128) name(uint32_t *out, const uint32_t *a, const uint32_t *b, int n) { \
    int i = video_variant_idx(n); \
    if (i < 0) return; \
    uint32_t d = 0; \
    uint32_t ai = a[i]; \
    uint32_t bi = b[i]; \
    uint32_t ci = (cinit); \
    asm volatile(ptx : "=r"(d) : "r"(ai), "r"(bi), "r"(ci)); \
    out[i] = d; \
}

VIDEO_VARIANT(video_variant_vadd_sat,
    "vadd.s32.s32.s32.sat %0, %1, %2;",
    0u)

VIDEO_VARIANT(video_variant_vsub_sat,
    "vsub.s32.s32.s32.sat %0, %1, %2;",
    0u)

VIDEO_VARIANT(video_variant_vabsdiff_add,
    "vabsdiff.u32.u32.u32.add %0, %1.b0, %2.b0, %3;",
    0x11223344u)

VIDEO_VARIANT(video_variant_vadd_merge_b0,
    "vadd.u32.u32.u32 %0.b0, %1.b0, %2.b0, %3;",
    0x55667788u)

VIDEO_VARIANT(video_variant_vsub_merge_h0,
    "vsub.s32.s32.s32.sat %0.h0, %1.h0, %2.h1, %3;",
    0x13572468u)

VIDEO_VARIANT(video_variant_vset_add_u32,
    "vset.u32.u32.lt.add %0, %1.b0, %2.b0, %3;",
    0x01020304u)

VIDEO_VARIANT(video_variant_vset_min_s32,
    "vset.s32.s32.lt.min %0, %1.h0, %2.h0, %3;",
    0x11223344u)

VIDEO_VARIANT(video_variant_vset_merge_b1,
    "vset.u32.u32.lt %0.b1, %1.b1, %2.b2, %3;",
    0x99aabbccu)

VIDEO_VARIANT(video_variant_vshl_add_clamp,
    "vshl.u32.u32.u32.clamp.add %0, %1.b0, %2.b0, %3;",
    0x11111111u)

VIDEO_VARIANT(video_variant_vshr_merge_wrap,
    "vshr.u32.u32.u32.wrap %0.b1, %1.h0, %2.b1, %3;",
    0x22222222u)

VIDEO_VARIANT(video_variant_vmad_shr7_sat,
    "vmad.s32.s32.s32.sat.shr7 %0, %1.h0, %2.h0, %3;",
    0x33333333u)

VIDEO_VARIANT(video_variant_vmad_po_shr15,
    "vmad.u32.u32.u32.po.shr15 %0, %1.h0, %2.h0, %3;",
    0x44444444u)

VIDEO_VARIANT(video_variant_vabsdiff2_base,
    "vabsdiff2.u32.u32.u32 %0, %1, %2, %3;",
    0x01010101u)

VIDEO_VARIANT(video_variant_vabsdiff2_add,
    "vabsdiff2.u32.u32.u32.add %0, %1, %2, %3;",
    0x02020202u)

VIDEO_VARIANT(video_variant_vadd2_sat,
    "vadd2.s32.s32.s32.sat %0, %1, %2, %3;",
    0x03030303u)

VIDEO_VARIANT(video_variant_vadd4_sat,
    "vadd4.s32.s32.s32.sat %0, %1, %2, %3;",
    0x04040404u)

VIDEO_VARIANT(video_variant_vset2_add,
    "vset2.u32.u32.lt.add %0, %1, %2, %3;",
    0x05050505u)

VIDEO_VARIANT(video_variant_vset4_add,
    "vset4.u32.u32.lt.add %0, %1, %2, %3;",
    0x06060606u)
