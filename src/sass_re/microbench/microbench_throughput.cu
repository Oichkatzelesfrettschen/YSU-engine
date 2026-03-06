/*
 * SASS RE: Instruction Throughput Microbenchmark
 *
 * Measures per-instruction throughput (instructions per clock per SM).
 *
 * Method:
 *   Unlike latency (serial chain), throughput uses INDEPENDENT operations.
 *   We launch enough warps to saturate the SM, then time a large block
 *   of independent instructions. Throughput = total_ops / total_cycles.
 *
 * Key insight:
 *   Ada Lovelace has 128 FP32 units per SM (4 sub-partitions x 2 FP32 pipelines x 16 lanes).
 *   So peak FP32 throughput = 128 ops/clock/SM.
 *   MUFU (SFU) throughput = 16 ops/clock/SM (1 pipe per sub-partition).
 *   INT32 throughput = 64 ops/clock/SM on Ada (or 128 if concurrent with FP32).
 *
 * Build: nvcc -arch=sm_89 -O1 -o throughput_bench.exe microbench_throughput.cu
 * Run:   throughput_bench.exe
 */

#include <stdio.h>
#include <cuda_runtime.h>

#define CHECK_CUDA(call) do { \
    cudaError_t err = (call); \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                cudaGetErrorString(err)); \
        exit(1); \
    } \
} while(0)

// Number of independent operations per thread
#define OPS_PER_THREAD 1024

// We want enough threads to fill the SM:
// 2048 max resident threads per SM on Ada (64 warps)
// Launch 2048 threads per block, 1 block
#define THREADS_PER_BLOCK 1024
#define NUM_BLOCKS 1

// ============================================================
// Throughput kernels: each thread does OPS_PER_THREAD INDEPENDENT ops
// ============================================================

// FADD throughput: many independent additions
__global__ void bench_fadd_throughput(float *out) {
    // Use 8 independent accumulators to expose ILP
    float a0 = 1.0f, a1 = 2.0f, a2 = 3.0f, a3 = 4.0f;
    float a4 = 5.0f, a5 = 6.0f, a6 = 7.0f, a7 = 8.0f;
    float b = 0.001f;

    #pragma unroll
    for (int i = 0; i < OPS_PER_THREAD / 8; i++) {
        a0 = a0 + b;  // All independent of each other
        a1 = a1 + b;
        a2 = a2 + b;
        a3 = a3 + b;
        a4 = a4 + b;
        a5 = a5 + b;
        a6 = a6 + b;
        a7 = a7 + b;
    }

    out[threadIdx.x + blockIdx.x * blockDim.x] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

// FFMA throughput
__global__ void bench_ffma_throughput(float *out) {
    float a0 = 1.0f, a1 = 2.0f, a2 = 3.0f, a3 = 4.0f;
    float a4 = 5.0f, a5 = 6.0f, a6 = 7.0f, a7 = 8.0f;
    float b = 1.001f, c = 0.001f;

    #pragma unroll
    for (int i = 0; i < OPS_PER_THREAD / 8; i++) {
        a0 = __fmaf_rn(a0, b, c);
        a1 = __fmaf_rn(a1, b, c);
        a2 = __fmaf_rn(a2, b, c);
        a3 = __fmaf_rn(a3, b, c);
        a4 = __fmaf_rn(a4, b, c);
        a5 = __fmaf_rn(a5, b, c);
        a6 = __fmaf_rn(a6, b, c);
        a7 = __fmaf_rn(a7, b, c);
    }

    out[threadIdx.x + blockIdx.x * blockDim.x] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

// MUFU throughput (SFU)
__global__ void bench_mufu_throughput(float *out) {
    float a0 = 2.0f, a1 = 3.0f, a2 = 4.0f, a3 = 5.0f;
    float a4 = 6.0f, a5 = 7.0f, a6 = 8.0f, a7 = 9.0f;

    #pragma unroll
    for (int i = 0; i < OPS_PER_THREAD / 8; i++) {
        a0 = __frcp_rn(a0);
        a1 = __frcp_rn(a1);
        a2 = __frcp_rn(a2);
        a3 = __frcp_rn(a3);
        a4 = __frcp_rn(a4);
        a5 = __frcp_rn(a5);
        a6 = __frcp_rn(a6);
        a7 = __frcp_rn(a7);
    }

    out[threadIdx.x + blockIdx.x * blockDim.x] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

// IADD3 throughput
__global__ void bench_iadd3_throughput(int *out) {
    int a0 = 1, a1 = 2, a2 = 3, a3 = 4;
    int a4 = 5, a5 = 6, a6 = 7, a7 = 8;
    int b = 1, c = 1;

    #pragma unroll
    for (int i = 0; i < OPS_PER_THREAD / 8; i++) {
        a0 = a0 + b + c;
        a1 = a1 + b + c;
        a2 = a2 + b + c;
        a3 = a3 + b + c;
        a4 = a4 + b + c;
        a5 = a5 + b + c;
        a6 = a6 + b + c;
        a7 = a7 + b + c;
    }

    out[threadIdx.x + blockIdx.x * blockDim.x] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;
}

// LOP3 throughput
__global__ void bench_lop3_throughput(unsigned *out) {
    unsigned a0 = 0xDEAD, a1 = 0xBEEF, a2 = 0xCAFE, a3 = 0xBABE;
    unsigned a4 = 0x1234, a5 = 0x5678, a6 = 0x9ABC, a7 = 0xDEF0;
    unsigned b = 0xAAAAAAAA, c = 0x55555555;

    #pragma unroll
    for (int i = 0; i < OPS_PER_THREAD / 8; i++) {
        a0 = (a0 & b) | (~a0 & c);
        a1 = (a1 & b) | (~a1 & c);
        a2 = (a2 & b) | (~a2 & c);
        a3 = (a3 & b) | (~a3 & c);
        a4 = (a4 & b) | (~a4 & c);
        a5 = (a5 & b) | (~a5 & c);
        a6 = (a6 & b) | (~a6 & c);
        a7 = (a7 & b) | (~a7 & c);
    }

    out[threadIdx.x + blockIdx.x * blockDim.x] = a0 ^ a1 ^ a2 ^ a3 ^ a4 ^ a5 ^ a6 ^ a7;
}

// FP32+INT32 concurrent throughput test
// If Ada can issue FP32 and INT32 concurrently, this should be faster
// than either alone.
__global__ void bench_fp_int_concurrent(float *fout, int *iout) {
    float f0 = 1.0f, f1 = 2.0f, f2 = 3.0f, f3 = 4.0f;
    int   i0 = 1,    i1 = 2,    i2 = 3,    i3 = 4;
    float fb = 0.001f;
    int   ib = 1;

    #pragma unroll
    for (int j = 0; j < OPS_PER_THREAD / 8; j++) {
        f0 = f0 + fb;
        i0 = i0 + ib;
        f1 = f1 + fb;
        i1 = i1 + ib;
        f2 = f2 + fb;
        i2 = i2 + ib;
        f3 = f3 + fb;
        i3 = i3 + ib;
    }

    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    fout[idx] = f0 + f1 + f2 + f3;
    iout[idx] = i0 + i1 + i2 + i3;
}


// ============================================================
// Host driver
// ============================================================

typedef void (*throughput_kernel_float_t)(float*);
typedef void (*throughput_kernel_int_t)(int*);
typedef void (*throughput_kernel_uint_t)(unsigned*);

struct ThroughputResult {
    const char *name;
    double ops_per_clock_per_sm;
    double total_gops;
};

static double measure_throughput_float(const char *name, throughput_kernel_float_t kernel,
                                        int threads_per_block, int num_blocks,
                                        cudaDeviceProp *prop) {
    int total_threads = threads_per_block * num_blocks;
    float *d_out;
    CHECK_CUDA(cudaMalloc(&d_out, total_threads * sizeof(float)));

    // Warmup
    kernel<<<num_blocks, threads_per_block>>>(d_out);
    CHECK_CUDA(cudaDeviceSynchronize());

    // Time it
    cudaEvent_t start, stop;
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));

    int iterations = 10;
    CHECK_CUDA(cudaEventRecord(start));
    for (int i = 0; i < iterations; i++) {
        kernel<<<num_blocks, threads_per_block>>>(d_out);
    }
    CHECK_CUDA(cudaEventRecord(stop));
    CHECK_CUDA(cudaEventSynchronize(stop));

    float ms;
    CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));

    double total_ops = (double)total_threads * OPS_PER_THREAD * iterations;
    double seconds = ms / 1000.0;
    double gops = total_ops / seconds / 1e9;

    // Ops per clock per SM
    int clockKHz = 0;
    cudaDeviceGetAttribute(&clockKHz, cudaDevAttrClockRate, 0);
    double clock_hz = (double)clockKHz * 1000.0;
    double total_clocks = seconds * clock_hz;
    double ops_per_clock = total_ops / total_clocks;
    double ops_per_clock_per_sm = ops_per_clock / prop->multiProcessorCount;

    CHECK_CUDA(cudaEventDestroy(start));
    CHECK_CUDA(cudaEventDestroy(stop));
    CHECK_CUDA(cudaFree(d_out));

    return ops_per_clock_per_sm;
}

int main() {
    cudaDeviceProp prop;
    CHECK_CUDA(cudaGetDeviceProperties(&prop, 0));
    printf("=== SASS Instruction Throughput Benchmark ===\n");
    printf("GPU: %s (SM %d.%d)\n", prop.name, prop.major, prop.minor);
    int clockKHz = 0;
    cudaDeviceGetAttribute(&clockKHz, cudaDevAttrClockRate, 0);
    printf("Clock: %d MHz\n", clockKHz / 1000);
    printf("SMs: %d\n", prop.multiProcessorCount);
    printf("Max threads/SM: %d\n", prop.maxThreadsPerMultiProcessor);
    printf("Threads/block: %d, Blocks: %d\n", THREADS_PER_BLOCK, NUM_BLOCKS);
    printf("Ops/thread: %d\n\n", OPS_PER_THREAD);

    // For SM-saturating test, launch enough blocks to fill all SMs
    int sat_blocks = prop.multiProcessorCount;

    printf("Running benchmarks (SM-saturating: %d blocks)...\n\n", sat_blocks);

    printf("%-25s %15s %15s\n", "Instruction", "ops/clk/SM", "expected");
    printf("%-25s %15s %15s\n", "-------------------------", "---------------", "---------------");

    double r;

    r = measure_throughput_float("FADD", bench_fadd_throughput, THREADS_PER_BLOCK, sat_blocks, &prop);
    printf("%-25s %15.1f %15s\n", "FADD", r, "128");

    r = measure_throughput_float("FFMA", bench_ffma_throughput, THREADS_PER_BLOCK, sat_blocks, &prop);
    printf("%-25s %15.1f %15s\n", "FFMA", r, "128");

    r = measure_throughput_float("MUFU (RCP)", bench_mufu_throughput, THREADS_PER_BLOCK, sat_blocks, &prop);
    printf("%-25s %15.1f %15s\n", "MUFU (RCP)", r, "16");

    // INT benchmarks need int* output
    {
        int total_threads = THREADS_PER_BLOCK * sat_blocks;
        int *d_out;
        CHECK_CUDA(cudaMalloc(&d_out, total_threads * sizeof(int)));

        bench_iadd3_throughput<<<sat_blocks, THREADS_PER_BLOCK>>>(d_out);
        CHECK_CUDA(cudaDeviceSynchronize());

        cudaEvent_t start, stop;
        CHECK_CUDA(cudaEventCreate(&start));
        CHECK_CUDA(cudaEventCreate(&stop));
        int iterations = 10;
        CHECK_CUDA(cudaEventRecord(start));
        for (int i = 0; i < iterations; i++)
            bench_iadd3_throughput<<<sat_blocks, THREADS_PER_BLOCK>>>(d_out);
        CHECK_CUDA(cudaEventRecord(stop));
        CHECK_CUDA(cudaEventSynchronize(stop));
        float ms;
        CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
        double total_ops = (double)total_threads * OPS_PER_THREAD * iterations;
        double seconds = ms / 1000.0;
        double clock_hz = (double)clockKHz * 1000.0;
        double total_clocks = seconds * clock_hz;
        r = total_ops / total_clocks / prop.multiProcessorCount;
        printf("%-25s %15.1f %15s\n", "IADD3", r, "64-128");

        CHECK_CUDA(cudaEventDestroy(start));
        CHECK_CUDA(cudaEventDestroy(stop));
        CHECK_CUDA(cudaFree(d_out));
    }

    // LOP3
    {
        int total_threads = THREADS_PER_BLOCK * sat_blocks;
        unsigned *d_out;
        CHECK_CUDA(cudaMalloc(&d_out, total_threads * sizeof(unsigned)));

        bench_lop3_throughput<<<sat_blocks, THREADS_PER_BLOCK>>>((unsigned*)d_out);
        CHECK_CUDA(cudaDeviceSynchronize());

        cudaEvent_t start, stop;
        CHECK_CUDA(cudaEventCreate(&start));
        CHECK_CUDA(cudaEventCreate(&stop));
        int iterations = 10;
        CHECK_CUDA(cudaEventRecord(start));
        for (int i = 0; i < iterations; i++)
            bench_lop3_throughput<<<sat_blocks, THREADS_PER_BLOCK>>>((unsigned*)d_out);
        CHECK_CUDA(cudaEventRecord(stop));
        CHECK_CUDA(cudaEventSynchronize(stop));
        float ms;
        CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
        double total_ops = (double)total_threads * OPS_PER_THREAD * iterations;
        double seconds = ms / 1000.0;
        double clock_hz = (double)clockKHz * 1000.0;
        double total_clocks = seconds * clock_hz;
        r = total_ops / total_clocks / prop.multiProcessorCount;
        printf("%-25s %15.1f %15s\n", "LOP3", r, "64-128");

        CHECK_CUDA(cudaEventDestroy(start));
        CHECK_CUDA(cudaEventDestroy(stop));
        CHECK_CUDA(cudaFree(d_out));
    }

    // FP32+INT32 concurrent
    {
        int total_threads = THREADS_PER_BLOCK * sat_blocks;
        float *d_fout;
        int *d_iout;
        CHECK_CUDA(cudaMalloc(&d_fout, total_threads * sizeof(float)));
        CHECK_CUDA(cudaMalloc(&d_iout, total_threads * sizeof(int)));

        bench_fp_int_concurrent<<<sat_blocks, THREADS_PER_BLOCK>>>(d_fout, d_iout);
        CHECK_CUDA(cudaDeviceSynchronize());

        cudaEvent_t start, stop;
        CHECK_CUDA(cudaEventCreate(&start));
        CHECK_CUDA(cudaEventCreate(&stop));
        int iterations = 10;
        CHECK_CUDA(cudaEventRecord(start));
        for (int i = 0; i < iterations; i++)
            bench_fp_int_concurrent<<<sat_blocks, THREADS_PER_BLOCK>>>(d_fout, d_iout);
        CHECK_CUDA(cudaEventRecord(stop));
        CHECK_CUDA(cudaEventSynchronize(stop));
        float ms;
        CHECK_CUDA(cudaEventElapsedTime(&ms, start, stop));
        // Total ops = FP + INT = both contribute OPS_PER_THREAD/2 each
        double total_ops = (double)total_threads * OPS_PER_THREAD * iterations;
        double seconds = ms / 1000.0;
        double clock_hz = (double)clockKHz * 1000.0;
        double total_clocks = seconds * clock_hz;
        r = total_ops / total_clocks / prop.multiProcessorCount;
        printf("%-25s %15.1f %15s\n", "FP32+INT32 concurrent", r, ">128 if concurrent");

        CHECK_CUDA(cudaEventDestroy(start));
        CHECK_CUDA(cudaEventDestroy(stop));
        CHECK_CUDA(cudaFree(d_fout));
        CHECK_CUDA(cudaFree(d_iout));
    }

    printf("\nNotes:\n");
    printf("  - 'ops/clk/SM' = instruction throughput per SM per clock cycle.\n");
    printf("  - Ada SM has 128 FP32 CUDA cores -> peak 128 FP32 ops/clk/SM.\n");
    printf("  - MUFU (SFU) has 16 units/SM -> peak 16 ops/clk/SM.\n");
    printf("  - If FP32+INT32 > 128, the GPU executes them on separate datapaths.\n");
    printf("  - Values below peak indicate register pressure or scheduling limits.\n");

    return 0;
}
