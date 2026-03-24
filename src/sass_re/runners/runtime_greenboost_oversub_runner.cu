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

static __global__ void page_touch_kernel(float *data,
                                         size_t page_count,
                                         size_t page_stride_elems,
                                         int rounds) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t p = tid; p < page_count; p += stride) {
            size_t idx = p * page_stride_elems;
            float x = data[idx];
            data[idx] = x + 1.0f;
        }
    }
}

static __global__ void hot_window_kernel(float *data,
                                         size_t elems,
                                         int iters) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < iters; ++r) {
        for (size_t i = tid; i < elems; i += stride) {
            float x = data[i];
            data[i] = x * 1.00001f + 0.00001f;
        }
    }
}

static __global__ void hopping_window_kernel(float *data,
                                             size_t total_elems,
                                             size_t window_elems,
                                             size_t hop_elems,
                                             int passes) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    if (window_elems == 0 || total_elems == 0) {
        return;
    }
    size_t max_base = (total_elems > window_elems) ? (total_elems - window_elems) : 0;
    for (int pass = 0; pass < passes; ++pass) {
        size_t base = ((size_t)pass * hop_elems);
        if (max_base != 0) {
            base %= max_base;
        } else {
            base = 0;
        }
        for (size_t i = tid; i < window_elems; i += stride) {
            size_t idx = base + i;
            float x = data[idx];
            data[idx] = x * 1.00001f + 0.00001f;
        }
    }
}

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

static float launch_page_touch(cudaStream_t stream,
                               float *ptr,
                               size_t page_count,
                               size_t page_stride_elems,
                               int blocks,
                               int threads,
                               int rounds) {
    cudaEvent_t start = NULL;
    cudaEvent_t stop = NULL;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    page_touch_kernel<<<blocks, threads, 0, stream>>>(ptr, page_count, page_stride_elems, rounds);
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
    CHECK_CUDA(cudaEventDestroy(stop));
    CHECK_CUDA(cudaEventDestroy(start));
    return ms;
}

static float launch_hot_window(cudaStream_t stream,
                               float *ptr,
                               size_t hot_elems,
                               int blocks,
                               int threads,
                               int iters) {
    cudaEvent_t start = NULL;
    cudaEvent_t stop = NULL;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    hot_window_kernel<<<blocks, threads, 0, stream>>>(ptr, hot_elems, iters);
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
    CHECK_CUDA(cudaEventDestroy(stop));
    CHECK_CUDA(cudaEventDestroy(start));
    return ms;
}

static float launch_hopping_window(cudaStream_t stream,
                                   float *ptr,
                                   size_t total_elems,
                                   size_t window_elems,
                                   size_t hop_elems,
                                   int blocks,
                                   int threads,
                                   int passes) {
    cudaEvent_t start = NULL;
    cudaEvent_t stop = NULL;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    hopping_window_kernel<<<blocks, threads, 0, stream>>>(
        ptr, total_elems, window_elems, hop_elems, passes);
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
    CHECK_CUDA(cudaEventDestroy(stop));
    CHECK_CUDA(cudaEventDestroy(start));
    return ms;
}

int main(int argc, char **argv) {
    const size_t bytes = (argc > 1) ? strtoull(argv[1], NULL, 10)
                                    : (size_t)(14ull * 1024ull * 1024ull * 1024ull);
    const char *mode = (argc > 2) ? argv[2] : "full";
    const size_t page_size = 4096;
    const size_t page_stride_elems = page_size / sizeof(float);
    const size_t page_count = bytes / page_size;
    const size_t hot_window_bytes = (bytes < (size_t)(256ull * 1024ull * 1024ull))
                                  ? bytes
                                  : (size_t)(256ull * 1024ull * 1024ull);
    const size_t hot_window_elems = hot_window_bytes / sizeof(float);
    const size_t total_elems = bytes / sizeof(float);
    const size_t hop_window_bytes = (bytes < (size_t)(64ull * 1024ull * 1024ull))
                                  ? bytes
                                  : (size_t)(64ull * 1024ull * 1024ull);
    const size_t hop_window_elems = hop_window_bytes / sizeof(float);
    const size_t hop_bytes = (size_t)(512ull * 1024ull * 1024ull);
    const size_t hop_elems = hop_bytes / sizeof(float);
    const int threads = 256;
    const int blocks = 128;

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
    printf("page_size=%zu\n", page_size);
    printf("page_count=%zu\n", page_count);
    printf("mode=%s\n", mode);
    printf("hot_window_bytes=%zu\n", hot_window_bytes);
    printf("hop_window_bytes=%zu\n", hop_window_bytes);
    printf("hop_bytes=%zu\n", hop_bytes);
    printf("free_before=%zu\n", free_before);
    printf("total_before=%zu\n", total_before);
    printf("env_GREENBOOST_ACTIVE=%s\n", getenv("GREENBOOST_ACTIVE") ? getenv("GREENBOOST_ACTIVE") : "");
    printf("env_GREENBOOST_USE_DMA_BUF=%s\n", getenv("GREENBOOST_USE_DMA_BUF") ? getenv("GREENBOOST_USE_DMA_BUF") : "");
    printf("env_GREENBOOST_NO_HOSTREG=%s\n", getenv("GREENBOOST_NO_HOSTREG") ? getenv("GREENBOOST_NO_HOSTREG") : "");
    printf("env_GREENBOOST_VRAM_HEADROOM_MB=%s\n", getenv("GREENBOOST_VRAM_HEADROOM_MB") ? getenv("GREENBOOST_VRAM_HEADROOM_MB") : "");
    fflush(stdout);

    float *ptr = NULL;
    double alloc_t0 = now_ms();
    CHECK_CUDA(cudaMalloc((void **)&ptr, bytes));
    double alloc_t1 = now_ms();

    float first_touch_ms = 0.0f;
    float second_touch_ms = 0.0f;
    float hot_first_ms = 0.0f;
    float hot_second_ms = 0.0f;
    float hop_first_ms = 0.0f;
    float hop_second_ms = 0.0f;

    if (strcmp(mode, "full") == 0) {
        first_touch_ms = launch_page_touch(stream, ptr, page_count, page_stride_elems, blocks, threads, 1);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        second_touch_ms = launch_page_touch(stream, ptr, page_count, page_stride_elems, blocks, threads, 1);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        hot_first_ms = launch_hot_window(stream, ptr, hot_window_elems, blocks, threads, 8);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        hot_second_ms = launch_hot_window(stream, ptr, hot_window_elems, blocks, threads, 8);
        CHECK_CUDA(cudaStreamSynchronize(stream));
    } else if (strcmp(mode, "hot_only") == 0) {
        hot_first_ms = launch_hot_window(stream, ptr, hot_window_elems, blocks, threads, 32);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        hot_second_ms = launch_hot_window(stream, ptr, hot_window_elems, blocks, threads, 32);
        CHECK_CUDA(cudaStreamSynchronize(stream));
    } else if (strcmp(mode, "hop") == 0) {
        hop_first_ms = launch_hopping_window(
            stream, ptr, total_elems, hop_window_elems, hop_elems, blocks, threads, 16);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        hop_second_ms = launch_hopping_window(
            stream, ptr, total_elems, hop_window_elems, hop_elems, blocks, threads, 16);
        CHECK_CUDA(cudaStreamSynchronize(stream));
    } else {
        fprintf(stderr, "unknown mode: %s\n", mode);
        return 2;
    }

    float sample[16];
    memset(sample, 0, sizeof(sample));
    CHECK_CUDA(cudaMemcpy(sample, ptr, sizeof(sample), cudaMemcpyDeviceToHost));
    double checksum = 0.0;
    for (int i = 0; i < 16; ++i) {
        checksum += sample[i];
    }

    double free_t0 = now_ms();
    CHECK_CUDA(cudaFree(ptr));
    double free_t1 = now_ms();

    size_t free_after = 0;
    size_t total_after = 0;
    CHECK_CUDA(cudaMemGetInfo(&free_after, &total_after));

    printf("alloc_ms=%.6f\n", alloc_t1 - alloc_t0);
    printf("first_touch_ms=%.6f\n", first_touch_ms);
    printf("second_touch_ms=%.6f\n", second_touch_ms);
    printf("hot_window_first_ms=%.6f\n", hot_first_ms);
    printf("hot_window_second_ms=%.6f\n", hot_second_ms);
    printf("hop_window_first_ms=%.6f\n", hop_first_ms);
    printf("hop_window_second_ms=%.6f\n", hop_second_ms);
    printf("free_ms=%.6f\n", free_t1 - free_t0);
    printf("sample_checksum=%.9f\n", checksum);
    printf("free_after=%zu\n", free_after);
    printf("total_after=%zu\n", total_after);

    CHECK_CUDA(cudaStreamDestroy(stream));
    return 0;
}
