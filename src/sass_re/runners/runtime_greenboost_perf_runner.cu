#include <cuda_runtime.h>

#include <math.h>
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

enum PatternKind {
    PATTERN_STREAM_RW = 0,
    PATTERN_READ_REDUCE = 1,
    PATTERN_STRIDE_RW = 2,
    PATTERN_COMPUTE_HEAVY = 3,
    PATTERN_COMPUTE_VERY_HEAVY = 4
};

static __global__ void init_kernel(float *data, size_t elems) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (size_t i = idx; i < elems; i += stride) {
        data[i] = (float)((i & 1023u) * 0.001f) + 1.0f;
    }
}

static __global__ void stream_rw_kernel(float *data, size_t elems, int rounds) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = idx; i < elems; i += stride) {
            float x = data[i];
            data[i] = x * 1.0001f + 0.0001f;
        }
    }
}

static __global__ void read_reduce_kernel(const float *data,
                                          float *partials,
                                          size_t elems,
                                          int rounds) {
    __shared__ float smem[256];
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    float sum = 0.0f;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = idx; i < elems; i += stride) {
            sum += data[i];
        }
    }
    smem[threadIdx.x] = sum;
    __syncthreads();
    for (unsigned offset = blockDim.x / 2; offset > 0; offset >>= 1) {
        if (threadIdx.x < offset) {
            smem[threadIdx.x] += smem[threadIdx.x + offset];
        }
        __syncthreads();
    }
    if (threadIdx.x == 0) {
        partials[blockIdx.x] = smem[0];
    }
}

static __global__ void stride_rw_kernel(float *data,
                                        size_t elems,
                                        size_t stride_elems,
                                        int rounds) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t worker_stride = (size_t)blockDim.x * gridDim.x;
    size_t touched = (elems + stride_elems - 1) / stride_elems;
    for (int r = 0; r < rounds; ++r) {
        for (size_t j = idx; j < touched; j += worker_stride) {
            size_t i = j * stride_elems;
            if (i < elems) {
                float x = data[i];
                data[i] = x * 1.0003f + 0.0007f;
            }
        }
    }
}

static __global__ void compute_heavy_kernel(float *data, size_t elems, int rounds) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = idx; i < elems; i += stride) {
            float x = data[i];
            #pragma unroll 32
            for (int k = 0; k < 32; ++k) {
                x = x * 1.00001f + 0.00001f;
            }
            data[i] = x;
        }
    }
}

static __global__ void compute_very_heavy_kernel(float *data, size_t elems, int rounds) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)blockDim.x * gridDim.x;
    for (int r = 0; r < rounds; ++r) {
        for (size_t i = idx; i < elems; i += stride) {
            float x = data[i];
            float y = x * 0.5f + 1.0f;
            #pragma unroll 1
            for (int k = 0; k < 256; ++k) {
                x = x * 1.000013f + y * 0.000017f + 0.000001f;
                y = y * 0.999981f + x * 0.000011f + 0.000003f;
            }
            data[i] = x + y * 0.25f;
        }
    }
}

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

static double bytes_moved(size_t elems,
                          int rounds,
                          PatternKind kind,
                          size_t stride_elems) {
    switch (kind) {
        case PATTERN_STREAM_RW:
            return (double)elems * sizeof(float) * 2.0 * rounds;
        case PATTERN_READ_REDUCE:
            return (double)elems * sizeof(float) * rounds;
        case PATTERN_STRIDE_RW: {
            size_t touched = (elems + stride_elems - 1) / stride_elems;
            return (double)touched * sizeof(float) * 2.0 * rounds;
        }
        case PATTERN_COMPUTE_HEAVY:
            return (double)elems * sizeof(float) * 2.0 * rounds;
        case PATTERN_COMPUTE_VERY_HEAVY:
            return (double)elems * sizeof(float) * 2.0 * rounds;
    }
    return 0.0;
}

static const char *pattern_name(PatternKind kind) {
    switch (kind) {
        case PATTERN_STREAM_RW: return "stream_rw";
        case PATTERN_READ_REDUCE: return "read_reduce";
        case PATTERN_STRIDE_RW: return "stride_rw";
        case PATTERN_COMPUTE_HEAVY: return "compute_heavy";
        case PATTERN_COMPUTE_VERY_HEAVY: return "compute_very_heavy";
    }
    return "unknown";
}

static float measure_pattern(cudaStream_t stream,
                             PatternKind kind,
                             float *data,
                             float *partials,
                             size_t elems,
                             int blocks,
                             int threads,
                             int rounds,
                             size_t stride_elems) {
    cudaEvent_t start = NULL;
    cudaEvent_t stop = NULL;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    switch (kind) {
        case PATTERN_STREAM_RW:
            stream_rw_kernel<<<blocks, threads, 0, stream>>>(data, elems, rounds);
            break;
        case PATTERN_READ_REDUCE:
            read_reduce_kernel<<<blocks, threads, 0, stream>>>(data, partials, elems, rounds);
            break;
        case PATTERN_STRIDE_RW:
            stride_rw_kernel<<<blocks, threads, 0, stream>>>(data, elems, stride_elems, rounds);
            break;
        case PATTERN_COMPUTE_HEAVY:
            compute_heavy_kernel<<<blocks, threads, 0, stream>>>(data, elems, rounds);
            break;
        case PATTERN_COMPUTE_VERY_HEAVY:
            compute_very_heavy_kernel<<<blocks, threads, 0, stream>>>(data, elems, rounds);
            break;
    }
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
                                    : (size_t)(256ull * 1024ull * 1024ull);
    const size_t elems = bytes / sizeof(float);
    const int threads = 256;
    const int blocks = 128;
    const int rounds = 4;
    const size_t stride_elems = 32;

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
    printf("rounds=%d\n", rounds);
    printf("stride_elems=%zu\n", stride_elems);
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

    float *partials = NULL;
    CHECK_CUDA(cudaMalloc((void **)&partials, (size_t)blocks * sizeof(float)));
    init_kernel<<<blocks, threads, 0, stream>>>(ptr, elems);
    CHECK_CUDA(cudaGetLastError());
    CHECK_CUDA(cudaStreamSynchronize(stream));

    for (int k = 0; k < 5; ++k) {
        PatternKind kind = (PatternKind)k;
        float first_ms = measure_pattern(stream, kind, ptr, partials, elems, blocks, threads, rounds, stride_elems);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        float second_ms = measure_pattern(stream, kind, ptr, partials, elems, blocks, threads, rounds, stride_elems);
        CHECK_CUDA(cudaStreamSynchronize(stream));
        double gib_moved = bytes_moved(elems, rounds, kind, stride_elems) / (1024.0 * 1024.0 * 1024.0);
        double gbps = (second_ms > 0.0f) ? (gib_moved / ((double)second_ms / 1000.0)) : 0.0;
        printf("pattern=%s first_ms=%.6f second_ms=%.6f gib=%.6f gib_per_s=%.6f\n",
               pattern_name(kind), first_ms, second_ms, gib_moved, gbps);
    }

    float sample[16];
    memset(sample, 0, sizeof(sample));
    CHECK_CUDA(cudaMemcpy(sample, ptr, sizeof(sample), cudaMemcpyDeviceToHost));
    double checksum = 0.0;
    for (int i = 0; i < 16; ++i) {
        checksum += sample[i];
    }

    double free_t0 = now_ms();
    CHECK_CUDA(cudaFree(partials));
    CHECK_CUDA(cudaFree(ptr));
    double free_t1 = now_ms();

    size_t free_after = 0;
    size_t total_after = 0;
    CHECK_CUDA(cudaMemGetInfo(&free_after, &total_after));

    printf("alloc_ms=%.6f\n", alloc_t1 - alloc_t0);
    printf("free_ms=%.6f\n", free_t1 - free_t0);
    printf("sample_checksum=%.9f\n", checksum);
    printf("free_after=%zu\n", free_after);
    printf("total_after=%zu\n", total_after);

    CHECK_CUDA(cudaStreamDestroy(stream));
    return 0;
}
