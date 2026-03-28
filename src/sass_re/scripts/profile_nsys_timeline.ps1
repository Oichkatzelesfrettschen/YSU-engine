<#
.SYNOPSIS
  Profile CUDA executables with NVIDIA Nsight Systems (nsys) for timeline analysis.

.DESCRIPTION
  Captures kernel launch timeline, GPU activity, memory transfers,
  CUDA API calls, and SM occupancy over time.
  Generates a .nsys-rep timeline and a GPU trace CSV summary.

.PARAMETER Executable
  Path to the CUDA executable to profile (required).

.PARAMETER Arguments
  Additional arguments to pass to the executable.

.PARAMETER OutputDir
  Directory for results (default: $env:NSYS_OUTDIR or results/nsys_<timestamp>).

.NOTES
  Equivalent of profile_nsys_timeline.sh.
  Requires: nsys (NVIDIA Nsight Systems CLI) and a live CUDA GPU.
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Executable,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Nsys = if ($env:NSYS) { $env:NSYS } else { "nsys" }

if (-not $OutputDir) {
    if ($env:NSYS_OUTDIR) {
        $OutputDir = $env:NSYS_OUTDIR
    } else {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputDir = Join-Path $PSScriptRoot ".." "results" "nsys_$Timestamp"
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$ArgsStr = if ($Arguments) { $Arguments -join ' ' } else { "" }

Write-Host "Nsight Systems timeline profiling" -ForegroundColor Cyan
Write-Host "Executable: $Executable $ArgsStr"
Write-Host "Output: $OutputDir"
Write-Host ""

$TimelineOutput = Join-Path $OutputDir "timeline"

# Trace: CUDA API, kernel launches, memory ops, OS runtime
$NsysArgs = @(
    "profile",
    "--trace=cuda,nvtx,osrt",
    "--cuda-memory-usage=true",
    "--gpu-metrics-device=all",
    "--output=$TimelineOutput",
    "--force-overwrite=true",
    "--",
    $Executable
)
if ($Arguments) {
    $NsysArgs += $Arguments
}

& $Nsys @NsysArgs

Write-Host ""
Write-Host "Timeline captured: ${TimelineOutput}.nsys-rep" -ForegroundColor Green
Write-Host "Open with: nsys-ui ${TimelineOutput}.nsys-rep"

# Generate summary stats
$GpuTraceOutput = Join-Path $OutputDir "gpu_trace"
try {
    & $Nsys stats "${TimelineOutput}.nsys-rep" `
        --report gputrace `
        --format csv `
        --output $GpuTraceOutput 2>$null
    Write-Host "GPU trace summary: ${GpuTraceOutput}.csv"
}
catch {
    Write-Host "GPU trace summary generation failed (non-fatal)." -ForegroundColor Yellow
}
