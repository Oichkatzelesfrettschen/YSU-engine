<#
.SYNOPSIS
  Mine unique SASS mnemonics from installed cuDNN libraries.

.DESCRIPTION
  Stream-extracts SASS disassembly from cuDNN shared libraries using
  cuobjdump, collects unique mnemonics, and diffs them against the
  checked-in mnemonic census to find novel instructions.

.PARAMETER OutputDir
  Directory for results (default: results/runs/cudnn_mining_<timestamp>).

.PARAMETER Profile
  Mining profile: 'core' (CNN/engines only) or 'all' (every cuDNN lib).
  Default: core. Override via $env:CUDNN_MINING_PROFILE.

.NOTES
  Equivalent of mine_cudnn_library_mnemonics.sh.
  Requires: cuobjdump, python3
#>

param(
    [string]$OutputDir,
    [ValidateSet("core", "all")]
    [string]$Profile
)

$ErrorActionPreference = "Stop"

$CuObjDump = if ($env:CUOBJDUMP) { $env:CUOBJDUMP } else { "cuobjdump" }
$Root = Split-Path $PSScriptRoot -Parent
$KnownCsv = if ($env:KNOWN_CSV) { $env:KNOWN_CSV } else {
    Join-Path $Root "results" "mnemonic_census.csv"
}
$KeepSass = if ($env:KEEP_SASS -eq "1") { $true } else { $false }
$MiningArch = if ($env:CUDNN_MINING_ARCH) { $env:CUDNN_MINING_ARCH } else { "sm_86" }
if (-not $Profile) {
    $Profile = if ($env:CUDNN_MINING_PROFILE) { $env:CUDNN_MINING_PROFILE } else { "core" }
}

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $Root "results" "runs" "cudnn_mining_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$CoreLibs = @(
    "libcudnn_cnn.so*",
    "libcudnn_engines_runtime_compiled.so*",
    "libcudnn_engines_precompiled.so*"
)
$AllLibs = $CoreLibs + @(
    "libcudnn_ops.so*",
    "libcudnn_adv.so*",
    "libcudnn_graph.so*"
)

$Patterns = if ($Profile -eq "all") { $AllLibs } else { $CoreLibs }

# Resolve library paths (Linux paths -- on Windows, adjust to CUDA install)
$LibDirs = @("/usr/lib", "/usr/lib64", "/usr/local/cuda/lib64")
$Libs = @()
foreach ($dir in $LibDirs) {
    if (Test-Path $dir) {
        foreach ($pat in $Patterns) {
            $found = Get-ChildItem -Path $dir -Filter $pat -ErrorAction SilentlyContinue
            foreach ($f in $found) {
                $resolved = $f.FullName
                if ($Libs -notcontains $resolved) {
                    $Libs += $resolved
                }
            }
        }
    }
}

if ($Libs.Count -eq 0) {
    Write-Error "No cuDNN libraries found"
    exit 1
}

$StatusCsv = Join-Path $OutputDir "status.csv"
"library,status,mnemonics" | Set-Content $StatusCsv
$CombinedTmp = Join-Path $OutputDir "combined.tmp"
"" | Set-Content $CombinedTmp

$MnemonicPattern = '^\s*/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)'

foreach ($lib in $Libs) {
    $base = Split-Path $lib -Leaf
    $outFile = Join-Path $OutputDir "$base.mnemonics.txt"
    $logFile = Join-Path $OutputDir "$base.cuobjdump.log"
    Write-Host "Mining: $base"

    try {
        $sassOutput = & $CuObjDump -arch $MiningArch -sass $lib 2>$logFile
        $mnemonics = $sassOutput | ForEach-Object {
            if ($_ -match $MnemonicPattern) { $Matches[1] }
        } | Sort-Object -Unique
        $mnemonics | Set-Content $outFile
        $count = $mnemonics.Count
        "$base,OK,$count" | Add-Content $StatusCsv
        $mnemonics | Add-Content $CombinedTmp
    }
    catch {
        "$base,FAIL,0" | Add-Content $StatusCsv
    }
}

$combined = Get-Content $CombinedTmp | Sort-Object -Unique
$combinedFile = Join-Path $OutputDir "combined_mnemonics.txt"
$combined | Set-Content $combinedFile
Remove-Item $CombinedTmp -ErrorAction SilentlyContinue

& python3 (Join-Path $PSScriptRoot "mnemonic_hunt.py") `
    --known $KnownCsv $combinedFile `
    > (Join-Path $OutputDir "novel_vs_checked_in.txt")

$summary = @"
cuDNN library mining complete.
arch=$MiningArch
profile=$Profile
results=$OutputDir
combined_mnemonics=$combinedFile
novel_vs_checked_in=$(Join-Path $OutputDir 'novel_vs_checked_in.txt')
"@
$summary | Set-Content (Join-Path $OutputDir "summary.txt")

Write-Host $OutputDir
