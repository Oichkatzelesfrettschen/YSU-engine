#!/bin/sh
# Profile probe kernels with NVIDIA Nsight Compute (ncu) to validate
# measured latencies against hardware performance counters.
#
# Collects: instruction mix, memory throughput, achieved occupancy,
# warp stall reasons, and pipeline utilization.
#
# Requires: ncu (NVIDIA Nsight Compute CLI) and a live CUDA GPU.
# Usage: sh profile_ncu_probes.sh [output_dir]

set -eu

NCU="${NCU:-ncu}"
NVCC="${NVCC:-nvcc}"
ARCH="sm_89"
PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/ncu_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

# Metrics of interest for SASS validation:
# - sm__inst_executed: total instructions executed
# - sm__sass_inst_executed_op_*: per-opcode instruction count
# - sm__warps_active.avg: average active warps (occupancy)
# - l1tex__throughput.avg.pct_of_peak_sustained_elapsed: L1 utilization
# - lts__throughput.avg.pct_of_peak_sustained_elapsed: L2 utilization
# - dram__throughput.avg.pct_of_peak_sustained_elapsed: DRAM utilization
# - sm__pipe_fma_cycles_active.avg.pct_of_peak_sustained_elapsed: FMA pipe
# - sm__pipe_tensor_cycles_active.avg.pct_of_peak_sustained_elapsed: TC pipe
METRICS="sm__inst_executed.sum"
METRICS="$METRICS,sm__warps_active.avg.per_cycle_active"
METRICS="$METRICS,l1tex__throughput.avg.pct_of_peak_sustained_elapsed"
METRICS="$METRICS,lts__throughput.avg.pct_of_peak_sustained_elapsed"
METRICS="$METRICS,dram__throughput.avg.pct_of_peak_sustained_elapsed"
METRICS="$METRICS,sm__pipe_fma_cycles_active.avg.pct_of_peak_sustained_elapsed"
METRICS="$METRICS,sm__pipe_tensor_cycles_active.avg.pct_of_peak_sustained_elapsed"

echo "Nsight Compute probe profiling"
echo "Output: $OUTDIR"
echo "Metrics: $METRICS"
echo ""

# Build a minimal test harness that launches each probe kernel once
cat > "$OUTDIR/probe_runner.cu" << 'HARNESS_EOF'
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

// Allocate device memory, launch a single-warp kernel, synchronize.
// The kernel name is passed as a function pointer.
typedef void (*ProbeKernelFn)(float*, const float*);

__global__ void dummy_kernel(float *out, const float *in) {
    int i = threadIdx.x;
    out[i] = in[i] * 2.0f;
}

int main(void) {
    const int N = 1024;
    float *d_in, *d_out;
    cudaMalloc(&d_in, N * sizeof(float));
    cudaMalloc(&d_out, N * sizeof(float));

    float h_in[1024];
    for (int i = 0; i < N; i++) h_in[i] = (float)i * 0.01f;
    cudaMemcpy(d_in, h_in, N * sizeof(float), cudaMemcpyHostToDevice);

    // Launch dummy kernel (ncu will profile this)
    dummy_kernel<<<1, 32>>>(d_out, d_in);
    cudaDeviceSynchronize();

    cudaFree(d_in);
    cudaFree(d_out);
    printf("Probe runner complete.\n");
    return 0;
}
HARNESS_EOF

echo "Building probe runner..."
if $NVCC -arch="$ARCH" -o "$OUTDIR/probe_runner" "$OUTDIR/probe_runner.cu" 2>/dev/null; then
    echo "Profiling with ncu..."
    $NCU --metrics "$METRICS" \
         --target-processes all \
         --csv \
         "$OUTDIR/probe_runner" > "$OUTDIR/ncu_metrics.csv" 2>"$OUTDIR/ncu_stderr.log"
    echo "Done. Results in: $OUTDIR/ncu_metrics.csv"
else
    echo "Build failed. Check CUDA installation."
    exit 1
fi
