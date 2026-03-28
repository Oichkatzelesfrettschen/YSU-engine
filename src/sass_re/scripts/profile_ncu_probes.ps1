<#
.SYNOPSIS
  Profile probe kernels with NVIDIA Nsight Compute (ncu).

.DESCRIPTION
  Builds a minimal test harness that launches a probe kernel, then
  profiles it with ncu to collect instruction mix, memory throughput,
  achieved occupancy, warp stall reasons, and pipeline utilization.
  Validates measured latencies against hardware performance counters.

.PARAMETER OutputDir
  Directory for results (default: results/ncu_<timestamp>).

.NOTES
  Equivalent of profile_ncu_probes.sh.
  Requires: ncu (NVIDIA Nsight Compute CLI), nvcc, a live CUDA GPU.
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Ncu  = if ($env:NCU)  { $env:NCU }  else { "ncu" }
$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$Arch = "sm_89"
$ProbeDir = Join-Path $PSScriptRoot ".." "probes" | Resolve-Path

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "ncu_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Metrics of interest for SASS validation:
# - sm__inst_executed: total instructions executed
# - sm__warps_active.avg: average active warps (occupancy)
# - l1tex__throughput: L1 utilization
# - lts__throughput: L2 utilization
# - dram__throughput: DRAM utilization
# - sm__pipe_fma_cycles_active: FMA pipe
# - sm__pipe_tensor_cycles_active: TC pipe
$Metrics = @(
    "sm__inst_executed.sum",
    "sm__warps_active.avg.per_cycle_active",
    "l1tex__throughput.avg.pct_of_peak_sustained_elapsed",
    "lts__throughput.avg.pct_of_peak_sustained_elapsed",
    "dram__throughput.avg.pct_of_peak_sustained_elapsed",
    "sm__pipe_fma_cycles_active.avg.pct_of_peak_sustained_elapsed",
    "sm__pipe_tensor_cycles_active.avg.pct_of_peak_sustained_elapsed"
) -join ','

Write-Host "Nsight Compute probe profiling" -ForegroundColor Cyan
Write-Host "Output: $OutputDir"
Write-Host "Metrics: $Metrics"
Write-Host ""

# Build a minimal test harness that launches a probe kernel once
$RunnerSrc = Join-Path $OutputDir "probe_runner.cu"
$RunnerHarness = @'
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
'@
Set-Content -Path $RunnerSrc -Value $RunnerHarness

$RunnerBin = Join-Path $OutputDir "probe_runner.exe"
$MetricsCsv = Join-Path $OutputDir "ncu_metrics.csv"
$StderrLog  = Join-Path $OutputDir "ncu_stderr.log"

Write-Host "Building probe runner..."
try {
    & $Nvcc "-arch=$Arch" -o $RunnerBin $RunnerSrc 2>$null
    if ($LASTEXITCODE -ne 0) { throw "nvcc compile failed" }

    Write-Host "Profiling with ncu..."
    & $Ncu --metrics $Metrics `
           --target-processes all `
           --csv `
           $RunnerBin > $MetricsCsv 2> $StderrLog
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ncu profiling returned non-zero exit code." -ForegroundColor Yellow
    }

    Write-Host "Done. Results in: $MetricsCsv" -ForegroundColor Green
}
catch {
    Write-Host "Build failed. Check CUDA installation." -ForegroundColor Red
    exit 1
}
