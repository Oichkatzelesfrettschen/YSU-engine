#include <cuda_runtime.h>
#include <cuda_pipeline.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK_CUDA(expr) do { \
    cudaError_t err__ = (expr); \
    if (err__ != cudaSuccess) { \
        fprintf(stderr, "CUDA error: %s (%d) at %s:%d\n", \
                cudaGetErrorString(err__), (int)err__, __FILE__, __LINE__); \
        return 1; \
    } \
} while (0)

static __global__ void tiny_launch_kernel(uint32_t *counter) {
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        counter[0] += 1u;
    }
}

static __global__ void l2_hot_window_kernel(float *out,
                                            const float *hot,
                                            const float *cold,
                                            int hot_mask,
                                            int cold_elems,
                                            int rounds) {
    int tid = (int)(blockIdx.x * blockDim.x + threadIdx.x);
    float acc = 0.0f;
    int hot_idx = (tid * 17) & hot_mask;
    int cold_idx = (tid * 257) % cold_elems;
    for (int r = 0; r < rounds; ++r) {
        acc += hot[(hot_idx + r * 32) & hot_mask];
        acc += cold[(cold_idx + r * 257) % cold_elems];
    }
    out[tid] = acc;
}

static __global__ void sync_stage_kernel(float *out, const float *in, int tiles) {
    __shared__ float smem[128];
    int tid = (int)threadIdx.x;
    int base = (int)(blockIdx.x * blockDim.x * tiles);
    float acc = 0.0f;
    for (int t = 0; t < tiles; ++t) {
        smem[tid] = in[base + t * (int)blockDim.x + tid];
        __syncthreads();
        acc += smem[tid] * 1.0001f;
        acc += smem[(tid + 17) & 127] * 0.9999f;
        __syncthreads();
    }
    out[base / tiles + tid] = acc;
}

static __global__ void async_stage_kernel(float *out, const float *in, int tiles) {
    __shared__ float smem[2][128];
    int tid = (int)threadIdx.x;
    int base = (int)(blockIdx.x * blockDim.x * tiles);
    float acc = 0.0f;
    int buf = 0;

    __pipeline_memcpy_async(&smem[buf][tid], &in[base + tid], sizeof(float));
    __pipeline_commit();

    for (int t = 0; t < tiles; ++t) {
        __pipeline_wait_prior(0);
        __syncthreads();
        acc += smem[buf][tid] * 1.0001f;
        acc += smem[buf][(tid + 17) & 127] * 0.9999f;
        __syncthreads();

        if (t + 1 < tiles) {
            int next = buf ^ 1;
            __pipeline_memcpy_async(&smem[next][tid],
                                    &in[base + (t + 1) * (int)blockDim.x + tid],
                                    sizeof(float));
            __pipeline_commit();
            buf = next;
        }
    }

    out[base / tiles + tid] = acc;
}

static float elapsed_ms(cudaEvent_t start, cudaEvent_t stop) {
    float ms = 0.0f;
    cudaEventElapsedTime(&ms, start, stop);
    return ms;
}

static float bench_l2_window(cudaStream_t stream,
                             float *d_out,
                             const float *d_hot,
                             const float *d_cold,
                             int blocks,
                             int threads,
                             int hot_mask,
                             int cold_elems,
                             int rounds,
                             int launches) {
    cudaEvent_t start = nullptr;
    cudaEvent_t stop = nullptr;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    for (int i = 0; i < launches; ++i) {
        l2_hot_window_kernel<<<blocks, threads, 0, stream>>>(
            d_out, d_hot, d_cold, hot_mask, cold_elems, rounds);
    }
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = elapsed_ms(start, stop) / (float)launches;
    cudaEventDestroy(stop);
    cudaEventDestroy(start);
    return ms;
}

static float bench_pipeline(cudaStream_t stream,
                            float *d_out,
                            const float *d_in,
                            int blocks,
                            int threads,
                            int tiles,
                            int launches,
                            int use_async) {
    cudaEvent_t start = nullptr;
    cudaEvent_t stop = nullptr;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    for (int i = 0; i < launches; ++i) {
        if (use_async) {
            async_stage_kernel<<<blocks, threads, 0, stream>>>(d_out, d_in, tiles);
        } else {
            sync_stage_kernel<<<blocks, threads, 0, stream>>>(d_out, d_in, tiles);
        }
    }
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float ms = elapsed_ms(start, stop) / (float)launches;
    cudaEventDestroy(stop);
    cudaEventDestroy(start);
    return ms;
}

static double bench_graph_launch(cudaStream_t stream, uint32_t *d_counter, int replays, int use_graph) {
    cudaGraph_t graph = nullptr;
    cudaGraphExec_t graph_exec = nullptr;
    cudaEvent_t start = nullptr;
    cudaEvent_t stop = nullptr;
    CHECK_CUDA(cudaMemsetAsync(d_counter, 0, sizeof(uint32_t), stream));
    CHECK_CUDA(cudaStreamSynchronize(stream));

    if (use_graph) {
        CHECK_CUDA(cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal));
        tiny_launch_kernel<<<1, 1, 0, stream>>>(d_counter);
        CHECK_CUDA(cudaStreamEndCapture(stream, &graph));
        CHECK_CUDA(cudaGraphInstantiate(&graph_exec, graph, NULL, NULL, 0));
    }

    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));
    CHECK_CUDA(cudaEventRecord(start, stream));
    for (int i = 0; i < replays; ++i) {
        if (use_graph) {
            CHECK_CUDA(cudaGraphLaunch(graph_exec, stream));
        } else {
            tiny_launch_kernel<<<1, 1, 0, stream>>>(d_counter);
        }
        CHECK_CUDA(cudaStreamSynchronize(stream));
    }
    CHECK_CUDA(cudaEventRecord(stop, stream));
    CHECK_CUDA(cudaEventSynchronize(stop));

    float ms = elapsed_ms(start, stop);
    cudaEventDestroy(stop);
    cudaEventDestroy(start);
    if (graph_exec != nullptr) {
        cudaGraphExecDestroy(graph_exec);
    }
    if (graph != nullptr) {
        cudaGraphDestroy(graph);
    }
    return ((double)ms * 1000.0) / (double)replays;
}

int main(void) {
    CHECK_CUDA(cudaSetDevice(0));

    cudaDeviceProp prop;
    CHECK_CUDA(cudaGetDeviceProperties(&prop, 0));
    printf("device=%s\n", prop.name);
    printf("sm=%d.%d\n", prop.major, prop.minor);
    printf("persisting_l2_max_bytes=%zu\n", (size_t)prop.persistingL2CacheMaxSize);
    printf("l2_cache_bytes=%d\n", prop.l2CacheSize);

    cudaStream_t stream;
    CHECK_CUDA(cudaStreamCreate(&stream));

    const int threads = 128;
    const int blocks = 64;
    const int hot_bytes = 4 * 1024 * 1024;
    const int hot_elems = hot_bytes / (int)sizeof(float);
    const int hot_mask = hot_elems - 1;
    const int cold_elems = (64 * 1024 * 1024) / (int)sizeof(float);
    const int rounds = 64;
    const int launches = 50;

    float *d_hot = nullptr;
    float *d_cold = nullptr;
    float *d_out = nullptr;
    CHECK_CUDA(cudaMalloc(&d_hot, (size_t)hot_elems * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_cold, (size_t)cold_elems * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_out, (size_t)blocks * (size_t)threads * sizeof(float)));
    CHECK_CUDA(cudaMemset(d_hot, 0, (size_t)hot_elems * sizeof(float)));
    CHECK_CUDA(cudaMemset(d_cold, 0, (size_t)cold_elems * sizeof(float)));
    CHECK_CUDA(cudaMemset(d_out, 0, (size_t)blocks * (size_t)threads * sizeof(float)));

    for (int i = 0; i < 8; ++i) {
        l2_hot_window_kernel<<<blocks, threads, 0, stream>>>(
            d_out, d_hot, d_cold, hot_mask, cold_elems, rounds);
    }
    CHECK_CUDA(cudaStreamSynchronize(stream));

    float l2_ms_off = bench_l2_window(
        stream, d_out, d_hot, d_cold, blocks, threads, hot_mask, cold_elems, rounds, launches);

    if (prop.persistingL2CacheMaxSize > 0) {
        size_t persist_bytes = (size_t)hot_bytes;
        if (persist_bytes > (size_t)prop.persistingL2CacheMaxSize) {
            persist_bytes = (size_t)prop.persistingL2CacheMaxSize;
        }
        CHECK_CUDA(cudaDeviceSetLimit(cudaLimitPersistingL2CacheSize, persist_bytes));
        cudaStreamAttrValue attr;
        memset(&attr, 0, sizeof(attr));
        attr.accessPolicyWindow.base_ptr = d_hot;
        attr.accessPolicyWindow.num_bytes = persist_bytes;
        attr.accessPolicyWindow.hitRatio = 1.0f;
        attr.accessPolicyWindow.hitProp = cudaAccessPropertyPersisting;
        attr.accessPolicyWindow.missProp = cudaAccessPropertyStreaming;
        CHECK_CUDA(cudaStreamSetAttribute(stream, cudaStreamAttributeAccessPolicyWindow, &attr));
    }

    float l2_ms_on = bench_l2_window(
        stream, d_out, d_hot, d_cold, blocks, threads, hot_mask, cold_elems, rounds, launches);

    {
        cudaStreamAttrValue attr;
        memset(&attr, 0, sizeof(attr));
        attr.accessPolicyWindow.num_bytes = 0;
        attr.accessPolicyWindow.hitProp = cudaAccessPropertyNormal;
        attr.accessPolicyWindow.missProp = cudaAccessPropertyNormal;
        CHECK_CUDA(cudaStreamSetAttribute(stream, cudaStreamAttributeAccessPolicyWindow, &attr));
    }

    uint32_t *d_counter = nullptr;
    CHECK_CUDA(cudaMalloc(&d_counter, sizeof(uint32_t)));
    double launch_plain_us = bench_graph_launch(stream, d_counter, 4000, 0);
    double launch_graph_us = bench_graph_launch(stream, d_counter, 4000, 1);

    const int pipe_tiles = 128;
    const int pipe_blocks = 256;
    const int pipe_elems = pipe_blocks * threads * pipe_tiles;
    float *d_pipe_in = nullptr;
    float *d_pipe_out = nullptr;
    CHECK_CUDA(cudaMalloc(&d_pipe_in, (size_t)pipe_elems * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_pipe_out, (size_t)pipe_blocks * (size_t)threads * sizeof(float)));
    CHECK_CUDA(cudaMemset(d_pipe_in, 0, (size_t)pipe_elems * sizeof(float)));
    CHECK_CUDA(cudaMemset(d_pipe_out, 0, (size_t)pipe_blocks * (size_t)threads * sizeof(float)));
    for (int i = 0; i < 8; ++i) {
        sync_stage_kernel<<<pipe_blocks, threads, 0, stream>>>(d_pipe_out, d_pipe_in, pipe_tiles);
        async_stage_kernel<<<pipe_blocks, threads, 0, stream>>>(d_pipe_out, d_pipe_in, pipe_tiles);
    }
    CHECK_CUDA(cudaStreamSynchronize(stream));
    float sync_ms = bench_pipeline(stream, d_pipe_out, d_pipe_in, pipe_blocks, threads, pipe_tiles, 40, 0);
    float async_ms = bench_pipeline(stream, d_pipe_out, d_pipe_in, pipe_blocks, threads, pipe_tiles, 40, 1);

    printf("l2_persist_off_ms=%.6f\n", l2_ms_off);
    printf("l2_persist_on_ms=%.6f\n", l2_ms_on);
    printf("l2_persist_speedup=%.6f\n", l2_ms_off / l2_ms_on);
    printf("graph_plain_launch_us=%.6f\n", launch_plain_us);
    printf("graph_replay_launch_us=%.6f\n", launch_graph_us);
    printf("graph_launch_speedup=%.6f\n", launch_plain_us / launch_graph_us);
    printf("pipeline_sync_ms=%.6f\n", sync_ms);
    printf("pipeline_async_ms=%.6f\n", async_ms);
    printf("pipeline_async_speedup=%.6f\n", sync_ms / async_ms);

    cudaFree(d_pipe_out);
    cudaFree(d_pipe_in);
    cudaFree(d_counter);
    cudaFree(d_out);
    cudaFree(d_cold);
    cudaFree(d_hot);
    cudaStreamDestroy(stream);
    return 0;
}
