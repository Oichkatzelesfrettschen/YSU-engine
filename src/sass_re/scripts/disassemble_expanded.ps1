<#
.SYNOPSIS
  Compile and disassemble the full recursive probe corpus for Ada SM 8.9.

.DESCRIPTION
  Reads the probe manifest TSV, compiles each enabled probe to a cubin
  with nvcc -arch=sm_89, then disassembles with cuobjdump -sass.
  Outputs mirrored .cubin/.sass/.reg artifacts plus a manifest snapshot.

.PARAMETER OutputDir
  Directory for results (default: results/runs/expanded_<timestamp>).

.NOTES
  Equivalent of disassemble_expanded.sh.
  Requires: nvcc, cuobjdump, python3
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Arch = "sm_89"
$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$CuObjDump = if ($env:CUOBJDUMP) { $env:CUOBJDUMP } else { "cuobjdump" }
$ManifestPy = Join-Path $PSScriptRoot "probe_manifest.py"

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "runs" "expanded_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$ManifestTsv = Join-Path $OutputDir "probe_manifest.tsv"
& python3 $ManifestPy emit --format tsv > $ManifestTsv

$Pass = 0
$Fail = 0

$Lines = Get-Content $ManifestTsv
foreach ($Line in $Lines) {
    $Fields = $Line -split "`t"
    if ($Fields.Count -lt 8) { continue }

    $ProbeId         = $Fields[0]
    $RelPath         = $Fields[1]
    $BaseName        = $Fields[2]
    $CompileEnabled  = $Fields[3]
    $RunnerKind      = $Fields[4]
    $SupportsGeneric = $Fields[5]
    $KernelNames     = $Fields[6]
    $SkipReason      = $Fields[7]

    if ($CompileEnabled -ne "1") {
        Write-Host "SKIP: $RelPath ($SkipReason)"
        continue
    }

    $Src     = Join-Path $PSScriptRoot ".." "probes" $RelPath
    $RelBase = $RelPath -replace '\.cu$', ''
    $Cubin   = Join-Path $OutputDir "$RelBase.cubin"
    $Sass    = Join-Path $OutputDir "$RelBase.sass"
    $Reg     = Join-Path $OutputDir "$RelBase.reg"

    $CubinDir = Split-Path $Cubin -Parent
    if (-not (Test-Path $CubinDir)) {
        New-Item -ItemType Directory -Path $CubinDir -Force | Out-Null
    }

    $PaddedPath = $RelPath.PadRight(48)
    Write-Host -NoNewline "$PaddedPath "

    try {
        & $Nvcc "-arch=$Arch" -cubin $Src -o $Cubin 2> $Reg
        if ($LASTEXITCODE -ne 0) { throw "nvcc failed" }

        & $CuObjDump -sass $Cubin > $Sass 2>$null
        $SassLines = (Get-Content $Sass | Measure-Object -Line).Lines
        $RegInfo = Select-String -Path $Reg -Pattern 'Used \d+ registers' |
                   Select-Object -Last 1
        $RegStr = if ($RegInfo) { $RegInfo.Matches[0].Value } else { "?" }
        Write-Host "OK  ($SassLines SASS lines, $RegStr)" -ForegroundColor Green
        $Pass++
    }
    catch {
        Write-Host "FAIL" -ForegroundColor Red
        if (Test-Path $Reg) {
            Get-Content $Reg | Write-Host
        }
        $Fail++
    }
}

Write-Host ""
Write-Host "Results in: $OutputDir"
Write-Host "Passed: $Pass  Failed: $Fail  Total: $($Pass + $Fail)"
