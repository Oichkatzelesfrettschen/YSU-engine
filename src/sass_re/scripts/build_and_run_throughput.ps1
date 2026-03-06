<#
.SYNOPSIS
  Build and run the throughput microbenchmark.
#>

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$BenchDir   = Join-Path $ScriptDir "..\microbench"
$ResultDir  = Join-Path $ScriptDir "..\results"

New-Item -ItemType Directory -Path $ResultDir -Force | Out-Null

$Src    = Join-Path $BenchDir "microbench_throughput.cu"
$Exe    = Join-Path $ResultDir "throughput_bench.exe"
$Output = Join-Path $ResultDir "throughput_results.txt"

Write-Host "=== Build & Run Throughput Benchmark ===" -ForegroundColor Cyan

Write-Host "Compiling $Src ..." -NoNewline
& nvcc -arch=sm_89 -O1 -lineinfo -o $Exe $Src 2>&1 | Tee-Object -Variable compileOut
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAILED" -ForegroundColor Red
    $compileOut
    exit 1
}
Write-Host " OK" -ForegroundColor Green

Write-Host ""
Write-Host "Running benchmark..." -ForegroundColor Yellow
& $Exe 2>&1 | Tee-Object -FilePath $Output
Write-Host ""
Write-Host "Results saved to: $Output" -ForegroundColor Cyan
