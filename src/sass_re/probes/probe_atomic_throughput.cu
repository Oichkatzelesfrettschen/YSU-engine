/*
 * SASS RE Probe: Atomic Operation Throughput at Various Contention Levels
 * Isolates: ATOM.E.ADD, ATOM.E.CAS, ATOMS (shared), RED (reduction)
 *
 * Atomic operations have radically different throughput depending on
 * contention level. This probe measures:
 *   1. Uncontended: each thread atomicAdds to its own address
 *   2. Warp-contended: 32 threads -> 1 address (intra-warp serialization)
 *   3. Block-contended: 128 threads -> 1 address
 *   4. Global-contended: many blocks -> 1 address (worst case)
 *
 * Ada Lovelace SM 8.9 has L2-based atomic units that can coalesce
 * atomics from the same warp to the same address. This probe reveals
 * how effective the coalescing is.
 *
 * Key SASS instructions:
 *   ATOM.E.ADD     -- global atomic add (returns old value)
 *   ATOM.E.ADD.F   -- global atomic float add
 *   RED.E.ADD      -- global reduction add (no return value, potentially faster)
 *   ATOMS.ADD      -- shared memory atomic add
 *   ATOM.E.CAS     -- compare-and-swap (building block for custom atomics)
 */

#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define CHECK(call) do { \
    cudaError_t e = (call); \
    if (e != cudaSuccess) { \
        fprintf(stderr, "CUDA %s:%d: %s\n", __FILE__, __LINE__, \
                cudaGetErrorString(e)); exit(1); \
    } \
} while(0)

#define ITERS 4096

/* Uncontended: each thread writes to its own address */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_uncontended(int *counters, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[i], 1);
}

/* Warp-contended: all 32 threads in a warp -> 1 address */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_warp_contended(int *counters, int n) {
    int warp_id = (threadIdx.x + blockIdx.x * blockDim.x) / 32;
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[warp_id], 1);
}

/* Block-contended: all 128 threads in a block -> 1 address */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_block_contended(int *counters, int n) {
    int block_id = blockIdx.x;
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[block_id], 1);
}

/* Global-contended: ALL threads -> 1 address (worst case) */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_global_contended(int *counters, int n) {
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[0], 1);
}

/* Float atomicAdd: same contention levels */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_float_uncontended(float *counters, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[i], 1.0f);
}

extern "C" __global__ void __launch_bounds__(128)
k_atomic_float_global(float *counters, int n) {
    for (int j = 0; j < ITERS; j++)
        atomicAdd(&counters[0], 1.0f);
}

/* Shared memory atomic: warp-contended */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_shared_warp(int *out) {
    __shared__ int smem[4];  // 4 warps in a block
    int warp = threadIdx.x / 32;
    if (threadIdx.x < 4) smem[threadIdx.x] = 0;
    __syncthreads();

    for (int j = 0; j < ITERS; j++)
        atomicAdd(&smem[warp], 1);
    __syncthreads();

    if (threadIdx.x < 4) out[blockIdx.x * 4 + threadIdx.x] = smem[threadIdx.x];
}

/* Shared memory atomic: all-contended (1 address) */
extern "C" __global__ void __launch_bounds__(128)
k_atomic_shared_all(int *out) {
    __shared__ int smem;
    if (threadIdx.x == 0) smem = 0;
    __syncthreads();

    for (int j = 0; j < ITERS; j++)
        atomicAdd(&smem, 1);
    __syncthreads();

    if (threadIdx.x == 0) out[blockIdx.x] = smem;
}

#ifndef SASS_RE_EMBEDDED_RUNNER
int main() {
    cudaDeviceProp prop;
    CHECK(cudaGetDeviceProperties(&prop, 0));
    int n_sms = prop.multiProcessorCount;

    printf("=== Atomic Throughput at Various Contention Levels ===\n");
    printf("SM %d.%d | %s | %d SMs | %d iters/thread\n\n",
           prop.major, prop.minor, prop.name, n_sms, ITERS);

    int n_threads = 128 * n_sms;  // 1 block per SM
    int *d_int; float *d_float; int *d_shared_out;
    CHECK(cudaMalloc(&d_int, n_threads * sizeof(int)));
    CHECK(cudaMalloc(&d_float, n_threads * sizeof(float)));
    CHECK(cudaMalloc(&d_shared_out, n_sms * 4 * sizeof(int)));
    CHECK(cudaMemset(d_int, 0, n_threads * sizeof(int)));
    CHECK(cudaMemset(d_float, 0, n_threads * sizeof(float)));

    cudaEvent_t start, stop;
    cudaEventCreate(&start); cudaEventCreate(&stop);

    printf("%-36s %12s %12s\n", "Pattern", "Time (ms)", "Ops/sec (G)");
    printf("%-36s %12s %12s\n",
           "------------------------------------", "------------", "------------");

    float ms; double total_ops, gops;

#define BENCH_INT(name, kernel) \
    CHECK(cudaMemset(d_int, 0, n_threads * sizeof(int))); \
    kernel<<<n_sms, 128>>>(d_int, n_threads); cudaDeviceSynchronize(); \
    cudaEventRecord(start); \
    kernel<<<n_sms, 128>>>(d_int, n_threads); \
    cudaEventRecord(stop); cudaEventSynchronize(stop); \
    cudaEventElapsedTime(&ms, start, stop); \
    total_ops = (double)n_sms * 128 * ITERS; \
    gops = total_ops / (ms * 1e6); \
    printf("%-36s %12.3f %12.2f\n", name, ms, gops);

#define BENCH_FLOAT(name, kernel) \
    CHECK(cudaMemset(d_float, 0, n_threads * sizeof(float))); \
    kernel<<<n_sms, 128>>>(d_float, n_threads); cudaDeviceSynchronize(); \
    cudaEventRecord(start); \
    kernel<<<n_sms, 128>>>(d_float, n_threads); \
    cudaEventRecord(stop); cudaEventSynchronize(stop); \
    cudaEventElapsedTime(&ms, start, stop); \
    total_ops = (double)n_sms * 128 * ITERS; \
    gops = total_ops / (ms * 1e6); \
    printf("%-36s %12.3f %12.2f\n", name, ms, gops);

#define BENCH_SHARED(name, kernel) \
    kernel<<<n_sms, 128>>>(d_shared_out); cudaDeviceSynchronize(); \
    cudaEventRecord(start); \
    kernel<<<n_sms, 128>>>(d_shared_out); \
    cudaEventRecord(stop); cudaEventSynchronize(stop); \
    cudaEventElapsedTime(&ms, start, stop); \
    total_ops = (double)n_sms * 128 * ITERS; \
    gops = total_ops / (ms * 1e6); \
    printf("%-36s %12.3f %12.2f\n", name, ms, gops);

    BENCH_INT("Int uncontended (per-thread addr)", k_atomic_uncontended);
    BENCH_INT("Int warp-contended (32->1)", k_atomic_warp_contended);
    BENCH_INT("Int block-contended (128->1)", k_atomic_block_contended);
    BENCH_INT("Int global-contended (all->1)", k_atomic_global_contended);
    BENCH_FLOAT("Float uncontended (per-thread)", k_atomic_float_uncontended);
    BENCH_FLOAT("Float global-contended (all->1)", k_atomic_float_global);
    BENCH_SHARED("Shared warp-contended (32->1)", k_atomic_shared_warp);
    BENCH_SHARED("Shared all-contended (128->1)", k_atomic_shared_all);

    printf("\n--- Analysis ---\n");
    printf("Uncontended atomics should approach memory BW limit.\n");
    printf("Contended atomics serialize at the L2 atomic unit.\n");
    printf("Shared atomics are faster (no L2 round-trip).\n");

    cudaEventDestroy(start); cudaEventDestroy(stop);
    cudaFree(d_int); cudaFree(d_float); cudaFree(d_shared_out);
    return 0;
}
#endif
