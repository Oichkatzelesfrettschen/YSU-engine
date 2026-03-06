<#
.SYNOPSIS
  Build and run the latency microbenchmark.

.DESCRIPTION
  Compiles microbench_latency.cu for SM 8.9, then runs it.
  Also dumps the SASS of the benchmark itself so you can verify
  the instruction chains are what you expect.
#>

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$BenchDir   = Join-Path $ScriptDir "..\microbench"
$ResultDir  = Join-Path $ScriptDir "..\results"

New-Item -ItemType Directory -Path $ResultDir -Force | Out-Null

$Src    = Join-Path $BenchDir "microbench_latency.cu"
$Exe    = Join-Path $ResultDir "latency_bench.exe"
$Cubin  = Join-Path $ResultDir "latency_bench.cubin"
$Sass   = Join-Path $ResultDir "latency_bench.sass"
$Output = Join-Path $ResultDir "latency_results.txt"

Write-Host "=== Build & Run Latency Benchmark ===" -ForegroundColor Cyan

# Step 1: Compile executable
Write-Host "Compiling $Src ..." -NoNewline
& nvcc -arch=sm_89 -O1 -lineinfo -o $Exe $Src 2>&1 | Tee-Object -Variable compileOut
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAILED" -ForegroundColor Red
    $compileOut
    exit 1
}
Write-Host " OK" -ForegroundColor Green

# Step 2: Also compile to cubin for SASS inspection
Write-Host "Compiling cubin for SASS dump..." -NoNewline
& nvcc -arch=sm_89 -O1 -cubin -lineinfo -o $Cubin $Src 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    & cuobjdump -sass $Cubin 2>&1 | Out-File -Encoding utf8 $Sass
    Write-Host " OK (see latency_bench.sass)" -ForegroundColor Green
} else {
    Write-Host " SKIPPED" -ForegroundColor DarkYellow
}

# Step 3: Run
Write-Host ""
Write-Host "Running benchmark..." -ForegroundColor Yellow
& $Exe 2>&1 | Tee-Object -FilePath $Output
Write-Host ""
Write-Host "Results saved to: $Output" -ForegroundColor Cyan
Write-Host "SASS dump at:     $Sass" -ForegroundColor Cyan
