<#
.SYNOPSIS
  Build the OptiX callable pipeline device PTX and host runner.

.PARAMETER PtxOut
  Output path for the device PTX file.

.PARAMETER RunnerOut
  Output path for the host runner binary.

.NOTES
  Equivalent of build_optix_callable_pipeline.sh.
  Requires: nvcc, OptiX headers
#>

param(
    [Parameter(Mandatory)][string]$PtxOut,
    [Parameter(Mandatory)][string]$RunnerOut
)

$ErrorActionPreference = "Stop"

$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$RunnerDir = Join-Path $PSScriptRoot ".." "runners"
$StdFlag = & (Join-Path $PSScriptRoot "resolve_nvcc_std_flag.ps1")

$PtxDir = Split-Path $PtxOut -Parent
$RunnerOutDir = Split-Path $RunnerOut -Parent
if ($PtxDir -and -not (Test-Path $PtxDir)) {
    New-Item -ItemType Directory -Path $PtxDir -Force | Out-Null
}
if ($RunnerOutDir -and -not (Test-Path $RunnerOutDir)) {
    New-Item -ItemType Directory -Path $RunnerOutDir -Force | Out-Null
}

$OptixInc = if ($env:OPTIX_INCLUDE) { $env:OPTIX_INCLUDE } else { "/usr/include/optix" }

& $Nvcc -arch=sm_89 $StdFlag -lineinfo --ptx --keep-device-functions `
    "-I/usr/include" "-I$OptixInc" `
    (Join-Path $RunnerDir "optix_callable_pipeline_device.cu") `
    -o $PtxOut
if ($LASTEXITCODE -ne 0) { throw "Device PTX compilation failed" }

& $Nvcc -arch=sm_89 $StdFlag -lineinfo `
    "-I/usr/include" "-I$OptixInc" `
    (Join-Path $RunnerDir "optix_callable_pipeline_runner.cu") `
    -o $RunnerOut -lcuda -ldl
if ($LASTEXITCODE -ne 0) { throw "Runner compilation failed" }
