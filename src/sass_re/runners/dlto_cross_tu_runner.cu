#include <cuda_runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// Forward declaration of the cross-TU DLTO kernel (defined in a separate
// translation unit linked at DLTO time).  The header
// "lto/dlto_stage_helpers.cuh" does not exist; only the kernel symbol is
// needed here.
extern "C" __global__ void probe_dlto_cross_tu(float *out,
                                               const float *a,
                                               const float *b,
                                               const float *base,
                                               int iters,
                                               uint64_t stride,
                                               int tail_mask,
                                               int stage_mask);

static int check_cuda(cudaError_t err, const char *file, int line) {
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA error: %s (%d) at %s:%d\n",
                cudaGetErrorString(err), (int)err, file, line);
        return 1;
    }
    return 0;
}
#define CHECK_CUDA(expr) do { if (check_cuda((expr), __FILE__, __LINE__)) return 1; } while (0)

static void fill_float(float *data, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        data[i] = ((int)(i % 257u) - 128) * 0.125f;
    }
}

int main(void) {
    const size_t kCount = 4096;
    const int iters = 8;
    const uint64_t stride = 64;
    const int tail_mask = 0x35;
    const int stage_mask = 0x4b;

    float *h_a = (float *)malloc(sizeof(float) * kCount);
    float *h_b = (float *)malloc(sizeof(float) * kCount);
    float *h_base = (float *)malloc(sizeof(float) * kCount);
    if (!h_a || !h_b || !h_base) {
        fprintf(stderr, "malloc failed\n");
        return 1;
    }
    fill_float(h_a, kCount);
    fill_float(h_b, kCount);
    fill_float(h_base, kCount);

    float *d_out = NULL;
    float *d_a = NULL;
    float *d_b = NULL;
    float *d_base = NULL;
    CHECK_CUDA(cudaMalloc(&d_out, sizeof(float) * kCount));
    CHECK_CUDA(cudaMalloc(&d_a, sizeof(float) * kCount));
    CHECK_CUDA(cudaMalloc(&d_b, sizeof(float) * kCount));
    CHECK_CUDA(cudaMalloc(&d_base, sizeof(float) * kCount));
    CHECK_CUDA(cudaMemcpy(d_a, h_a, sizeof(float) * kCount, cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_b, h_b, sizeof(float) * kCount, cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_base, h_base, sizeof(float) * kCount, cudaMemcpyHostToDevice));

    void *args[] = {
        &d_out, &d_a, &d_b, &d_base,
        (void *)&iters, (void *)&stride, (void *)&tail_mask, (void *)&stage_mask
    };
    CHECK_CUDA(cudaLaunchKernel((const void *)probe_dlto_cross_tu,
                                dim3(1, 1, 1), dim3(32, 1, 1),
                                args, 0, 0));
    CHECK_CUDA(cudaDeviceSynchronize());

    printf("dlto runner complete\n");

    cudaFree(d_out);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_base);
    free(h_a);
    free(h_b);
    free(h_base);
    return 0;
}
