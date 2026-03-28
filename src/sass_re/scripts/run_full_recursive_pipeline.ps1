<#
.SYNOPSIS
  Run the full recursive Ada pipeline into a single run root.

.DESCRIPTION
  Executes the complete recursive pipeline in sequence:
    1. disassemble_expanded  -- compile and disassemble all probes
    2. flag_matrix_sweep     -- flag matrix across all optimization lanes
    3. compile_profile_all   -- compile + profile + benchmark pipeline
    4. ncu_profile_all_probes -- Nsight Compute profiling of all probes
  All output is collected under the specified run root directory,
  with a combined log at full_recursive.log.

.PARAMETER RunRoot
  Absolute path to the run root directory (required).

.NOTES
  Equivalent of run_full_recursive_pipeline.sh.
  Requires: nvcc, cuobjdump, ncu, python3
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RunRoot
)

$ErrorActionPreference = "Stop"

$LogFile = Join-Path $RunRoot "full_recursive.log"

New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null

function Log-Pipeline {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $LogFile -Value $Message
}

Log-Pipeline "RUNROOT=$RunRoot"

# Phase 1: Disassemble expanded
Write-Host "=== Phase 1: Disassemble Expanded ===" -ForegroundColor Cyan
$DisasmDir = Join-Path $RunRoot "disassembly"
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "disassemble_expanded.ps1") -OutputDir $DisasmDir 2>&1 |
        Tee-Object -Append -FilePath $LogFile
}
catch {
    Log-Pipeline "Phase 1 failed: $_"
}

# Phase 2: Flag matrix sweep
Write-Host "=== Phase 2: Flag Matrix Sweep ===" -ForegroundColor Cyan
$LanesDir = Join-Path $RunRoot "lanes"
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flag_matrix_sweep.ps1") -OutputDir $LanesDir 2>&1 |
        Tee-Object -Append -FilePath $LogFile
}
catch {
    Log-Pipeline "Phase 2 failed: $_"
}

# Phase 3: Compile + profile
Write-Host "=== Phase 3: Compile + Profile ===" -ForegroundColor Cyan
$CompileProfileDir = Join-Path $RunRoot "compile_profile"
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "compile_profile_all.ps1") -OutputDir $CompileProfileDir 2>&1 |
        Tee-Object -Append -FilePath $LogFile
}
catch {
    Log-Pipeline "Phase 3 failed: $_"
}

# Phase 4: ncu full profile
Write-Host "=== Phase 4: ncu Profile All Probes ===" -ForegroundColor Cyan
$NcuDir = Join-Path $RunRoot "ncu"
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "ncu_profile_all_probes.ps1") -OutputDir $NcuDir 2>&1 |
        Tee-Object -Append -FilePath $LogFile
}
catch {
    Log-Pipeline "Phase 4 failed: $_"
}

Log-Pipeline "FULL_RECURSIVE_DONE"
