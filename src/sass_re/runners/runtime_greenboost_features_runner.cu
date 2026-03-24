#include <cuda_runtime.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CHECK_CUDA(expr) do { \
    cudaError_t err__ = (expr); \
    if (err__ != cudaSuccess) { \
        fprintf(stderr, "CUDA error: %s (%d) at %s:%d\n", \
                cudaGetErrorString(err__), (int)err__, __FILE__, __LINE__); \
        return 1; \
    } \
} while (0)

static __global__ void greenboost_touch_kernel(float *data, size_t elems, int rounds) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = tid; i < elems; i += stride) {
            data[i] = data[i] * 1.0001f + 0.0001f;
        }
    }
}

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

static float event_ms(cudaStream_t stream,
                      float *data,
                      size_t elems,
                      int blocks,
                      int threads,
                      int rounds) {
    cudaEvent_t start = nullptr;
    cudaEvent_t stop = nullptr;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    greenboost_touch_kernel<<<blocks, threads, 0, stream>>>(data, elems, rounds);
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
    cudaEventDestroy(stop);
    cudaEventDestroy(start);
    return ms;
}

int main(int argc, char **argv) {
    const size_t bytes = (argc > 1) ? strtoull(argv[1], NULL, 10) : (size_t)(512ull * 1024ull * 1024ull);
    const size_t elems = bytes / sizeof(float);
    const int threads = 256;
    const int blocks = 128;
    const int rounds = 4;

    CHECK_CUDA(cudaSetDevice(0));

    cudaDeviceProp prop;
    CHECK_CUDA(cudaGetDeviceProperties(&prop, 0));

    size_t free_before = 0;
    size_t total_before = 0;
    CHECK_CUDA(cudaMemGetInfo(&free_before, &total_before));

    cudaStream_t stream;
    CHECK_CUDA(cudaStreamCreate(&stream));

    printf("device=%s\n", prop.name);
    printf("sm=%d.%d\n", prop.major, prop.minor);
    printf("bytes=%zu\n", bytes);
    printf("elems=%zu\n", elems);
    printf("free_before=%zu\n", free_before);
    printf("total_before=%zu\n", total_before);
    printf("env_GREENBOOST_ACTIVE=%s\n", getenv("GREENBOOST_ACTIVE") ? getenv("GREENBOOST_ACTIVE") : "");
    printf("env_GREENBOOST_USE_DMA_BUF=%s\n", getenv("GREENBOOST_USE_DMA_BUF") ? getenv("GREENBOOST_USE_DMA_BUF") : "");
    printf("env_GREENBOOST_NO_HOSTREG=%s\n", getenv("GREENBOOST_NO_HOSTREG") ? getenv("GREENBOOST_NO_HOSTREG") : "");
    printf("env_GREENBOOST_VRAM_HEADROOM_MB=%s\n", getenv("GREENBOOST_VRAM_HEADROOM_MB") ? getenv("GREENBOOST_VRAM_HEADROOM_MB") : "");
    fflush(stdout);

    float *ptr = nullptr;
    double t0 = now_ms();
    CHECK_CUDA(cudaMalloc((void **)&ptr, bytes));
    double t1 = now_ms();

    CHECK_CUDA(cudaMemsetAsync(ptr, 0, bytes, stream));
    CHECK_CUDA(cudaStreamSynchronize(stream));

    float first_ms = event_ms(stream, ptr, elems, blocks, threads, rounds);
    CHECK_CUDA(cudaStreamSynchronize(stream));
    float second_ms = event_ms(stream, ptr, elems, blocks, threads, rounds);
    CHECK_CUDA(cudaStreamSynchronize(stream));

    float sample[16];
    memset(sample, 0, sizeof(sample));
    CHECK_CUDA(cudaMemcpy(sample, ptr, sizeof(sample), cudaMemcpyDeviceToHost));
    double checksum = 0.0;
    for (int i = 0; i < 16; ++i) checksum += sample[i];

    double t2 = now_ms();
    CHECK_CUDA(cudaFree(ptr));
    double t3 = now_ms();

    size_t free_after = 0;
    size_t total_after = 0;
    CHECK_CUDA(cudaMemGetInfo(&free_after, &total_after));

    printf("alloc_ms=%.6f\n", t1 - t0);
    printf("first_kernel_ms=%.6f\n", first_ms);
    printf("second_kernel_ms=%.6f\n", second_ms);
    printf("free_ms=%.6f\n", t3 - t2);
    printf("sample_checksum=%.9f\n", checksum);
    printf("free_after=%zu\n", free_after);
    printf("total_after=%zu\n", total_after);

    CHECK_CUDA(cudaStreamDestroy(stream));
    return 0;
}
