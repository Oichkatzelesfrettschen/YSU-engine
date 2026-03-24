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

static __global__ void managed_stream_kernel(float *data, size_t elems, int rounds) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = tid; i < elems; i += stride) {
            data[i] = data[i] * 1.0001f + 0.0001f;
        }
    }
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
    managed_stream_kernel<<<blocks, threads, 0, stream>>>(data, elems, rounds);
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
    cudaEventDestroy(stop);
    cudaEventDestroy(start);
    return ms;
}

static double host_touch_ms(float *data, size_t elems) {
    volatile float sink = 0.0f;
    const uint64_t begin = (uint64_t)clock();
    for (size_t i = 0; i < elems; i += 1024) {
        sink = sink + data[i];
        data[i] = sink + 1.0f;
    }
    const uint64_t end = (uint64_t)clock();
    return ((double)(end - begin) * 1000.0) / (double)CLOCKS_PER_SEC;
}

int main(void) {
    CHECK_CUDA(cudaSetDevice(0));

    cudaDeviceProp prop;
    CHECK_CUDA(cudaGetDeviceProperties(&prop, 0));
    printf("device=%s\n", prop.name);
    printf("sm=%d.%d\n", prop.major, prop.minor);
    printf("total_global_mem=%zu\n", (size_t)prop.totalGlobalMem);
    printf("managed_memory=%d\n", (int)prop.managedMemory);
    printf("concurrent_managed_access=%d\n", (int)prop.concurrentManagedAccess);
    printf("pageable_memory_access=%d\n", (int)prop.pageableMemoryAccess);
    printf("direct_managed_mem_access_from_host=%d\n", (int)prop.directManagedMemAccessFromHost);
    fflush(stdout);

    cudaStream_t stream;
    CHECK_CUDA(cudaStreamCreate(&stream));

    cudaMemLocation gpu_loc;
    memset(&gpu_loc, 0, sizeof(gpu_loc));
    gpu_loc.type = cudaMemLocationTypeDevice;
    gpu_loc.id = 0;

    cudaMemLocation cpu_loc;
    memset(&cpu_loc, 0, sizeof(cpu_loc));
    cpu_loc.type = cudaMemLocationTypeHost;
    cpu_loc.id = 0;

    const size_t bytes = 64ull * 1024ull * 1024ull;
    const size_t elems = bytes / sizeof(float);
    const int threads = 256;
    const int blocks = 128;
    const int rounds = 2;

    float *managed = nullptr;
    CHECK_CUDA(cudaMallocManaged(&managed, bytes));

    for (size_t i = 0; i < elems; ++i) {
        managed[i] = (float)(i & 255u) * 0.00390625f;
    }

    CHECK_CUDA(cudaDeviceSynchronize());

    float cold_gpu_ms = event_ms(stream, managed, elems, blocks, threads, rounds);
    CHECK_CUDA(cudaStreamSynchronize(stream));

    for (size_t i = 0; i < elems; i += 1024) {
        managed[i] += 1.0f;
    }
    CHECK_CUDA(cudaDeviceSynchronize());

    CHECK_CUDA(cudaMemPrefetchAsync(managed, bytes, gpu_loc, 0, stream));
    CHECK_CUDA(cudaStreamSynchronize(stream));
    float prefetched_gpu_ms = event_ms(stream, managed, elems, blocks, threads, rounds);
    CHECK_CUDA(cudaStreamSynchronize(stream));

    CHECK_CUDA(cudaMemAdvise(managed, bytes, cudaMemAdviseSetPreferredLocation, gpu_loc));
    CHECK_CUDA(cudaMemAdvise(managed, bytes, cudaMemAdviseSetReadMostly, gpu_loc));
    CHECK_CUDA(cudaMemPrefetchAsync(managed, bytes, gpu_loc, 0, stream));
    CHECK_CUDA(cudaStreamSynchronize(stream));
    float advised_gpu_ms = event_ms(stream, managed, elems, blocks, threads, rounds);
    CHECK_CUDA(cudaStreamSynchronize(stream));

    double host_cold_ms = host_touch_ms(managed, elems);
    CHECK_CUDA(cudaMemPrefetchAsync(managed, bytes, cpu_loc, 0, stream));
    CHECK_CUDA(cudaStreamSynchronize(stream));
    double host_prefetch_ms = host_touch_ms(managed, elems);

    printf("managed_bytes=%zu\n", bytes);
    printf("managed_elems=%zu\n", elems);
    printf("gpu_cold_ms=%.6f\n", cold_gpu_ms);
    printf("gpu_prefetch_ms=%.6f\n", prefetched_gpu_ms);
    printf("gpu_advise_prefetch_ms=%.6f\n", advised_gpu_ms);
    printf("host_touch_cold_ms=%.6f\n", host_cold_ms);
    printf("host_touch_prefetch_ms=%.6f\n", host_prefetch_ms);

    if (prefetched_gpu_ms > 0.0f) {
        printf("gpu_prefetch_speedup=%.6f\n", (double)cold_gpu_ms / (double)prefetched_gpu_ms);
    }
    if (advised_gpu_ms > 0.0f) {
        printf("gpu_advise_prefetch_speedup=%.6f\n", (double)cold_gpu_ms / (double)advised_gpu_ms);
    }
    if (host_prefetch_ms > 0.0) {
        printf("host_prefetch_speedup=%.6f\n", host_cold_ms / host_prefetch_ms);
    }
    fflush(stdout);

    CHECK_CUDA(cudaFree(managed));
    CHECK_CUDA(cudaStreamDestroy(stream));
    return 0;
}
