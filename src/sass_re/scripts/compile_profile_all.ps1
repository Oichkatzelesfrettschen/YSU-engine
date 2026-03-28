<#
.SYNOPSIS
  Full compile + profile pipeline for the recursive probe corpus.

.DESCRIPTION
  Phase 1: Compile every enabled probe with high-signal optimization flags,
           disassemble, and extract per-probe stats to CSV.
  Phase 2: Build and run latency benchmarks, collecting results to CSV.
  Produces a combined mnemonic inventory.

.PARAMETER OutputDir
  Directory for results (default: results/runs/full_profile_<timestamp>).

.NOTES
  Equivalent of compile_profile_all.sh.
  Requires: nvcc, cuobjdump, python3
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$NvccStdFlag = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "resolve_nvcc_std_flag.ps1") -NvccBin $Nvcc
$BenchDir  = Join-Path $PSScriptRoot ".." "microbench" | Resolve-Path
$ProbeDir  = Join-Path $PSScriptRoot ".." "probes"     | Resolve-Path
$ManifestPy = Join-Path $PSScriptRoot "probe_manifest.py"

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "runs" "full_profile_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$Flags = "-arch=sm_89 -O3 -Xptxas -O3,-warn-double-usage,-warn-spills --use_fast_math --extra-device-vectorization --restrict --default-stream per-thread $NvccStdFlag -lineinfo"
$FlagArray = $Flags -split '\s+'

$ManifestTsv = Join-Path $OutputDir "probe_manifest.tsv"
& python3 $ManifestPy emit --format tsv > $ManifestTsv

$PipelineLog = Join-Path $OutputDir "pipeline.log"
function Log-Line {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $PipelineLog -Value $Message
}

Log-Line "=== Full Compile + Profile Pipeline ==="
Log-Line "Flags: $Flags"
Log-Line "Output: $OutputDir"
Log-Line ""

# CSV header
$Csv = Join-Path $OutputDir "probe_stats.csv"
Set-Content -Path $Csv -Value "probe_id,relative_path,compiled,sass_lines,unique_mnemonics,max_registers,spill_stores,spill_loads,status"

# Phase 1: Compile + disassemble all probes
Log-Line "=== Phase 1: Compile + Disassemble ==="
$Pass = 0
$Fail = 0

$TsvLines = Get-Content $ManifestTsv
foreach ($Line in $TsvLines) {
    $Fields = $Line -split "`t"
    if ($Fields.Count -lt 8) { continue }

    $ProbeId         = $Fields[0]
    $RelPath         = $Fields[1]
    $CompileEnabled  = $Fields[3]

    if ($CompileEnabled -ne "1") { continue }

    $Src     = Join-Path $PSScriptRoot ".." "probes" $RelPath
    $RelBase = $RelPath -replace '\.cu$', ''
    $Cubin   = Join-Path $OutputDir "$RelBase.cubin"
    $Sass    = Join-Path $OutputDir "$RelBase.sass"
    $RegLog  = Join-Path $OutputDir "$RelBase.reg"

    $CubinDir = Split-Path $Cubin -Parent
    if (-not (Test-Path $CubinDir)) {
        New-Item -ItemType Directory -Path $CubinDir -Force | Out-Null
    }

    try {
        & $Nvcc @FlagArray -Xptxas -v -cubin $Src -o $Cubin 2> $RegLog
        if ($LASTEXITCODE -ne 0) { throw "nvcc failed" }

        & cuobjdump -sass $Cubin > $Sass 2>$null

        # Count SASS instruction lines
        $SassLines = 0
        $UniqueSet = @{}
        $SassContent = Get-Content $Sass -ErrorAction SilentlyContinue
        foreach ($SassLine in $SassContent) {
            if ($SassLine -match '^\s+/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)') {
                $SassLines++
                $UniqueSet[$Matches[1]] = $true
            }
        }
        $Unique = $UniqueSet.Count

        # Parse register and spill info
        $RegContent = Get-Content $RegLog -ErrorAction SilentlyContinue
        $Regs = 0
        $SpillSt = 0
        $SpillLd = 0
        foreach ($RegLine in $RegContent) {
            if ($RegLine -match 'Used (\d+) registers') {
                $r = [int]$Matches[1]
                if ($r -gt $Regs) { $Regs = $r }
            }
            if ($RegLine -match '(\d+) bytes spill stores') {
                $s = [int]$Matches[1]
                if ($s -gt $SpillSt) { $SpillSt = $s }
            }
            if ($RegLine -match '(\d+) bytes spill loads') {
                $l = [int]$Matches[1]
                if ($l -gt $SpillLd) { $SpillLd = $l }
            }
        }

        Add-Content -Path $Csv -Value "$ProbeId,$RelPath,1,$SassLines,$Unique,$Regs,$SpillSt,$SpillLd,OK"
        $Pass++
    }
    catch {
        Add-Content -Path $Csv -Value "$ProbeId,$RelPath,0,0,0,0,0,0,COMPILE_FAIL"
        $Fail++
    }
}

Log-Line "Compiled: $Pass  Failed: $Fail"

# Extract combined mnemonics
$AllMnemonics = Join-Path $OutputDir "all_mnemonics.txt"
$MnemSet = @{}
$SassFiles = Get-ChildItem -Path $OutputDir -Filter "*.sass" -Recurse -File -ErrorAction SilentlyContinue
foreach ($SassFile in $SassFiles) {
    $Content = Get-Content $SassFile.FullName -ErrorAction SilentlyContinue
    foreach ($SassLine in $Content) {
        if ($SassLine -match '^\s+/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)') {
            $MnemSet[$Matches[1]] = $true
        }
    }
}
$MnemSet.Keys | Sort-Object | Set-Content -Path $AllMnemonics
$TotalMnem = $MnemSet.Count
Log-Line "Total unique mnemonics: $TotalMnem"

# Phase 2: Compile and run latency benchmarks
Log-Line ""
Log-Line "=== Phase 2: Latency Benchmarks ==="

$BenchCsv = Join-Path $OutputDir "benchmark_results.csv"
Set-Content -Path $BenchCsv -Value "benchmark,instruction,latency_cy,flags"

$Benchmarks = @(
    "microbench_latency",
    "microbench_latency_expanded",
    "microbench_latency_wave5",
    "microbench_latency_corrected",
    "microbench_latency_conversions",
    "microbench_latency_tensor_all",
    "microbench_remaining_latencies",
    "microbench_fill_all_na"
)

foreach ($Bench in $Benchmarks) {
    $BenchSrc = Join-Path $BenchDir "$Bench.cu"
    if (-not (Test-Path $BenchSrc)) { continue }

    $BenchBin = Join-Path $OutputDir "$Bench.exe"
    $CompileLog = Join-Path $OutputDir "${Bench}_compile.log"
    $BenchOutput = Join-Path $OutputDir "${Bench}_output.txt"

    Log-Line "  Building $Bench..."
    try {
        & $Nvcc @FlagArray "-I$ProbeDir" -o $BenchBin $BenchSrc 2> $CompileLog
        if ($LASTEXITCODE -ne 0) { throw "compile failed" }

        Log-Line "  Running $Bench..."
        & $BenchBin > $BenchOutput 2>&1
        # Extract latency lines to CSV
        $BenchLines = Get-Content $BenchOutput -ErrorAction SilentlyContinue
        foreach ($BLine in $BenchLines) {
            if ($BLine -match '^\S.*\s+(\d+\.\d+)$') {
                $Lat = $Matches[1]
                Add-Content -Path $BenchCsv -Value "$Bench,,$Lat,$Flags"
            }
        }
    }
    catch {
        Log-Line "  COMPILE FAIL: $Bench"
    }
}

Log-Line ""
Log-Line "=== Pipeline Complete ==="
Log-Line "Probe stats: $Csv"
Log-Line "Benchmark results: $BenchCsv"
Log-Line "Mnemonics: $AllMnemonics ($TotalMnem unique)"
