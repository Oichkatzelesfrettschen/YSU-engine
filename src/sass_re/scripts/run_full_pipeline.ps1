<#
.SYNOPSIS
  Full SASS reverse engineering pipeline.
  
.DESCRIPTION
  Runs the complete RE workflow:
    1. Compile all probe kernels and dump SASS disassembly
    2. Run encoding analysis (Python) on the disassembly results
    3. Build and run latency microbenchmark
    4. Build and run throughput microbenchmark
    5. Generate combined report

.NOTES
  Run from the repo root or set working directory to src/sass_re/.
  Requires: nvcc, cuobjdump, nvdisasm, python3
#>

param(
    [switch]$SkipProbes,       # Skip probe compilation if already done
    [switch]$SkipBenchmarks,   # Skip microbenchmarks
    [switch]$ProbesOnly,       # Only compile probes
    [switch]$BenchOnly         # Only run benchmarks
)

$ErrorActionPreference = "Stop"

# Find sass_re directory
$SassReDir = $null
if (Test-Path "src\sass_re\scripts") {
    $SassReDir = "src\sass_re"
} elseif (Test-Path "scripts\disassemble_all.ps1") {
    $SassReDir = "."
} else {
    Write-Host "ERROR: Run this from the repo root or src/sass_re/" -ForegroundColor Red
    exit 1
}

$ScriptsDir = Join-Path $SassReDir "scripts"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  SASS Reverse Engineering Pipeline" -ForegroundColor Cyan
Write-Host "  Target: SM 8.9 (Ada Lovelace / RTX 4070 Ti Super)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# ---- Phase 1: Probe disassembly ----
if (-not $SkipProbes -and -not $BenchOnly) {
    Write-Host "[Phase 1/4] Compiling probes and dumping SASS..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir "disassemble_all.ps1")
    Write-Host ""
}

# ---- Phase 2: Encoding analysis ----
if (-not $SkipProbes -and -not $BenchOnly) {
    Write-Host "[Phase 2/4] Running encoding analysis..." -ForegroundColor Yellow
    $ResultDir = Join-Path $SassReDir "results"
    # Find the most recent timestamped directory
    $latestRun = Get-ChildItem $ResultDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($latestRun) {
        $pythonExe = "python"
        if (Test-Path ".venv\Scripts\python.exe") {
            $pythonExe = ".venv\Scripts\python.exe"
        }
        & $pythonExe (Join-Path $ScriptsDir "encoding_analysis.py") $latestRun.FullName
    } else {
        Write-Host "  No probe results found, skipping analysis." -ForegroundColor DarkYellow
    }
    Write-Host ""
}

if ($ProbesOnly) {
    Write-Host "Done (probes only)." -ForegroundColor Cyan
    exit 0
}

# ---- Phase 3: Latency benchmark ----
if (-not $SkipBenchmarks) {
    Write-Host "[Phase 3/4] Running latency microbenchmark..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir "build_and_run_latency.ps1")
    Write-Host ""
}

# ---- Phase 4: Throughput benchmark ----
if (-not $SkipBenchmarks) {
    Write-Host "[Phase 4/4] Running throughput microbenchmark..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File (Join-Path $ScriptsDir "build_and_run_throughput.ps1")
    Write-Host ""
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Pipeline complete." -ForegroundColor Cyan
Write-Host "  Results in: $(Join-Path $SassReDir 'results')" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Read the .sass files to see actual SM 8.9 instruction encoding"
Write-Host "  2. Read ENCODING_ANALYSIS.md for bit-field patterns"
Write-Host "  3. Compare latency results against expected values"
Write-Host "  4. Compare throughput results against theoretical peaks"
Write-Host "  5. Use Nsight Compute for deeper profiling:"
Write-Host "     ncu --set full .\src\sass_re\results\latency_bench.exe"
