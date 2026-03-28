<#
.SYNOPSIS
  Probe nvcc for the highest supported C++ language mode.

.DESCRIPTION
  Compiles a trivial kernel with -std=c++23 and -std=c++20 in turn.
  Outputs the first accepted flag string to stdout.
  Exits non-zero if neither flag is accepted.

.PARAMETER NvccBin
  Path to the nvcc binary (default: $env:NVCC or 'nvcc').

.PARAMETER Arch
  Target architecture for the probe (default: $env:NVCC_STD_ARCH or 'sm_89').

.NOTES
  Equivalent of resolve_nvcc_std_flag.sh.
  Requires: nvcc
#>

param(
    [string]$NvccBin,
    [string]$Arch
)

$ErrorActionPreference = "Stop"

if (-not $NvccBin) {
    $NvccBin = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
}
if (-not $Arch) {
    $Arch = if ($env:NVCC_STD_ARCH) { $env:NVCC_STD_ARCH } else { "sm_89" }
}

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "nvcc_std_probe_$([System.Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

$Src = Join-Path $TmpDir "std_probe.cu"
$Obj = Join-Path $TmpDir "std_probe.o"

try {
    Set-Content -Path $Src -Value '__global__ void sass_re_std_probe_kernel(void) {}'

    function Test-NvccFlag {
        param([string]$Flag)
        $proc = Start-Process -FilePath $NvccBin `
            -ArgumentList "-arch=$Arch", $Flag, "-c", $Src, "-o", $Obj `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TmpDir "stdout.txt") `
            -RedirectStandardError  (Join-Path $TmpDir "stderr.txt")
        return ($proc.ExitCode -eq 0)
    }

    if (Test-NvccFlag "-std=c++23") {
        Write-Output "-std=c++23"
        exit 0
    }

    if (Test-NvccFlag "-std=c++20") {
        Write-Output "-std=c++20"
        exit 0
    }

    Write-Error "resolve_nvcc_std_flag.ps1: nvcc accepts neither -std=c++23 nor -std=c++20"
    exit 1
}
finally {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}
