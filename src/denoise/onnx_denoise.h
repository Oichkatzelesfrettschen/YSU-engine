#pragma once
#include "vec3.h"

#ifdef __cplusplus
extern "C" {
#endif

// Runs ONNX denoise if YSU_NEURAL_DENOISE=1.
// YSU_ONNX_MODEL="path/to/model.onnx"
// Expected IO: float32 NCHW [1,3,H,W] -> [1,3,H,W] (0..1 range)
void ysu_neural_denoise_maybe(Vec3 *pixels, int width, int height);

#ifdef __cplusplus
}
#endif
