#include <stdint.h>

static __device__ __forceinline__ int video_idx(int n) {
    int i = (int)(threadIdx.x + blockIdx.x * blockDim.x);
    return i < n ? i : -1;
}

#define VIDEO_ISA_KERNEL(name, ptx) \
extern "C" __global__ void __launch_bounds__(128) name(uint32_t *out, const uint32_t *a, const uint32_t *b, int n) { \
    int i = video_idx(n); \
    if (i < 0) return; \
    uint32_t d = 0; \
    uint32_t ai = a[i]; \
    uint32_t bi = b[i]; \
    uint32_t ci = 0u; \
    asm volatile(ptx : "=r"(d) : "r"(ai), "r"(bi), "r"(ci)); \
    out[i] = d; \
}

VIDEO_ISA_KERNEL(video_isa_vadd2,
    "vadd2.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vsub2,
    "vsub2.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vavrg2,
    "vavrg2.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmin2,
    "vmin2.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmax2,
    "vmax2.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmin2_s32,
    "vmin2.s32.s32.s32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmax2_s32,
    "vmax2.s32.s32.s32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vset2_lt,
    "vset2.u32.u32.lt %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vset2_lt_s32,
    "vset2.s32.s32.lt %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vadd4,
    "vadd4.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vsub4,
    "vsub4.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vavrg4,
    "vavrg4.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmin4,
    "vmin4.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmax4,
    "vmax4.u32.u32.u32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmin4_s32,
    "vmin4.s32.s32.s32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vmax4_s32,
    "vmax4.s32.s32.s32 %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vset4_lt,
    "vset4.u32.u32.lt %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vset4_lt_s32,
    "vset4.s32.s32.lt %0, %1, %2, %3;")

VIDEO_ISA_KERNEL(video_isa_vsadu4,
    "vabsdiff4.u32.u32.u32.add %0, %1, %2, %3;")
