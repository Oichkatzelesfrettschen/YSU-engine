#include <stdint.h>

static __device__ __forceinline__ int video_selector_idx(int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    return i < n ? i : -1;
}

#define VIDEO_SELECTOR(name, ptx, cinit) \
extern "C" __global__ void __launch_bounds__(128) name(uint32_t *out, const uint32_t *a, const uint32_t *b, int n) { \
    int i = video_selector_idx(n); \
    if (i < 0) return; \
    uint32_t d = 0; \
    uint32_t ai = a[i]; \
    uint32_t bi = b[i]; \
    uint32_t ci = (cinit); \
    asm volatile(ptx : "=r"(d) : "r"(ai), "r"(bi), "r"(ci)); \
    out[i] = d; \
}

VIDEO_SELECTOR(video_selector_vadd_merge_b0,
    "vadd.u32.u32.u32 %0.b0, %1.b0, %2.b2, %3;",
    0x55667788u)

VIDEO_SELECTOR(video_selector_vsub_merge_h1,
    "vsub.s32.s32.s32.sat %0.h1, %1.h0, %2.h1, %3;",
    0x13572468u)

VIDEO_SELECTOR(video_selector_vmin_merge_b2,
    "vmin.u32.u32.u32 %0.b2, %1.b1, %2.b3, %3;",
    0xaabbccddu)

VIDEO_SELECTOR(video_selector_vmax_merge_h0,
    "vmax.s32.s32.s32 %0.h0, %1.h1, %2.h0, %3;",
    0x10203040u)

VIDEO_SELECTOR(video_selector_vset_add_max,
    "vset.u32.u32.lt.max %0, %1.b0, %2.b1, %3;",
    0x01020304u)

VIDEO_SELECTOR(video_selector_vset_merge_h1,
    "vset.s32.s32.ge %0.h1, %1.h0, %2.h1, %3;",
    0x0f1e2d3cu)

VIDEO_SELECTOR(video_selector_vshl_b0_clamp,
    "vshl.u32.u32.u32.clamp %0, %1.b0, %2.b1;",
    0u)

VIDEO_SELECTOR(video_selector_vshr_h1_wrap,
    "vshr.s32.s32.u32.wrap %0, %1.h1, %2.b0;",
    0u)

VIDEO_SELECTOR(video_selector_vmad_b0,
    "vmad.u32.u32.u32 %0, %1.b0, %2.b1, %3;",
    0x11111111u)

VIDEO_SELECTOR(video_selector_vmad_h1_po,
    "vmad.u32.u32.u32.po %0, %1.h1, %2.h0, %3;",
    0x22222222u)

VIDEO_SELECTOR(video_selector_vmad_h0_shr7,
    "vmad.s32.s32.s32.sat.shr7 %0, %1.h0, %2.h1, %3;",
    0x33333333u)

VIDEO_SELECTOR(video_selector_vabsdiff2_h10,
    "vabsdiff2.u32.u32.u32 %0.h10, %1.h23, %2.h10, %3;",
    0x04040404u)

VIDEO_SELECTOR(video_selector_vabsdiff2_add_h0,
    "vabsdiff2.u32.u32.u32.add %0.h0, %1.h01, %2.h23, %3;",
    0x05050505u)

VIDEO_SELECTOR(video_selector_vset2_add_h10,
    "vset2.u32.u32.lt.add %0.h10, %1.h23, %2.h10, %3;",
    0x06060606u)

VIDEO_SELECTOR(video_selector_vset4_add_b3210,
    "vset4.u32.u32.lt.add %0.b3210, %1.b7654, %2.b3210, %3;",
    0x07070707u)
