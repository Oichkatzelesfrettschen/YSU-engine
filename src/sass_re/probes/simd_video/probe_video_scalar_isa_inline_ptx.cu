#include <stdint.h>

static __device__ __forceinline__ int video_scalar_idx(int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    return i < n ? i : -1;
}

#define VIDEO_SCALAR_2OP(name, ptx) \
extern "C" __global__ void __launch_bounds__(128) name(uint32_t *out, const uint32_t *a, const uint32_t *b, int n) { \
    int i = video_scalar_idx(n); \
    if (i < 0) return; \
    uint32_t d = 0; \
    uint32_t ai = a[i]; \
    uint32_t bi = b[i]; \
    asm volatile(ptx : "=r"(d) : "r"(ai), "r"(bi)); \
    out[i] = d; \
}

#define VIDEO_SCALAR_3OP(name, ptx, cinit) \
extern "C" __global__ void __launch_bounds__(128) name(uint32_t *out, const uint32_t *a, const uint32_t *b, int n) { \
    int i = video_scalar_idx(n); \
    if (i < 0) return; \
    uint32_t d = 0; \
    uint32_t ai = a[i]; \
    uint32_t bi = b[i]; \
    uint32_t ci = (cinit); \
    asm volatile(ptx : "=r"(d) : "r"(ai), "r"(bi), "r"(ci)); \
    out[i] = d; \
}

VIDEO_SCALAR_2OP(video_scalar_vadd_u32,
    "vadd.u32.u32.u32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vsub_u32,
    "vsub.u32.u32.u32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vabsdiff_u32,
    "vabsdiff.u32.u32.u32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vmin_u32,
    "vmin.u32.u32.u32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vmax_u32,
    "vmax.u32.u32.u32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vmin_s32,
    "vmin.s32.s32.s32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vmax_s32,
    "vmax.s32.s32.s32 %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vset_lt_u32,
    "vset.u32.u32.lt %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vset_lt_s32,
    "vset.s32.s32.lt %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vshl_clamp_u32,
    "vshl.u32.u32.u32.clamp %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vshr_wrap_u32,
    "vshr.u32.u32.u32.wrap %0, %1, %2;")

VIDEO_SCALAR_2OP(video_scalar_vshr_wrap_s32,
    "vshr.s32.s32.u32.wrap %0, %1, %2;")

VIDEO_SCALAR_3OP(video_scalar_vmad_u32,
    "vmad.u32.u32.u32 %0, %1, %2, %3;",
    0x11223344u)

VIDEO_SCALAR_3OP(video_scalar_vmad_po_u32,
    "vmad.u32.u32.u32.po %0, %1, %2, %3;",
    0x11223344u)

VIDEO_SCALAR_3OP(video_scalar_vmad_shr15_u32,
    "vmad.u32.u32.u32.shr15 %0, %1.h0, %2.h0, %3;",
    0x11223344u)

VIDEO_SCALAR_3OP(video_scalar_vmad_sat_s32,
    "vmad.s32.s32.u32.sat %0, %1.b0, %2.b0, -%3;",
    0x10203040u)
