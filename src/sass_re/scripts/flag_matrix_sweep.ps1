<#
.SYNOPSIS
  Comprehensive recursive compilation flag matrix sweep.

.DESCRIPTION
  Compiles every recursive probe with each flag lane, capturing:
    - Register counts and spills (via -Xptxas -v)
    - Raw emitted SASS mnemonics (via cuobjdump -sass)
    - Compilation success/failure, including diagnostic lanes
  Uses PowerShell jobs for parallel compilation and extraction.

.PARAMETER OutputDir
  Directory for results (default: results/runs/flag_sweep_<timestamp>).

.NOTES
  Equivalent of flag_matrix_sweep.sh.
  Requires: nvcc, cuobjdump, python3
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$NvccStdFlag = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "resolve_nvcc_std_flag.ps1") -NvccBin $Nvcc
$ManifestPy = Join-Path $PSScriptRoot "probe_manifest.py"
$SweepJobs = if ($env:FLAG_SWEEP_JOBS) { [int]$env:FLAG_SWEEP_JOBS } else { 6 }
$SweepExtractJobs = if ($env:FLAG_SWEEP_EXTRACT_JOBS) { [int]$env:FLAG_SWEEP_EXTRACT_JOBS } else { 4 }

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "runs" "flag_sweep_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$BaseFlags = "-arch=sm_89 $NvccStdFlag -lineinfo"
$BaseFlagArray = $BaseFlags -split '\s+'
$ManifestTsv = Join-Path $OutputDir "probe_manifest.tsv"
$Baseline = Join-Path $OutputDir "baseline_mnemonics.txt"
$CheckedInBaseline = Join-Path $OutputDir "checked_in_mnemonics.txt"

& python3 $ManifestPy emit --format tsv > $ManifestTsv

# Build the checked-in baseline from mnemonic_census.csv
$CensusPath = Join-Path $PSScriptRoot ".." "results" "mnemonic_census.csv"
if (Test-Path $CensusPath) {
    $CensusLines = Get-Content $CensusPath
    $CensusSet = @{}
    $First = $true
    foreach ($CLine in $CensusLines) {
        if ($First) { $First = $false; continue }
        $Cols = $CLine -split ','
        if ($Cols.Count -ge 2) { $CensusSet[$Cols[1]] = $true }
    }
    $CensusSet.Keys | Sort-Object | Set-Content -Path $CheckedInBaseline
}

$SweepLog = Join-Path $OutputDir "sweep.log"

function Log-Sweep {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $SweepLog -Value $Message
}

Log-Sweep "=== Flag Matrix Sweep ==="
Log-Sweep "Base: $BaseFlags"
Log-Sweep "Output: $OutputDir"
Log-Sweep "Compile jobs: $SweepJobs"
Log-Sweep "Extract jobs: $SweepExtractJobs"
Log-Sweep ""

function Invoke-CompileSet {
    param(
        [string]$Label,
        [string]$ExtraFlags
    )

    $Dir = Join-Path $OutputDir $Label
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null

    $ExtraFlagArray = @()
    if ($ExtraFlags) {
        $ExtraFlagArray = $ExtraFlags -split '\s+'
    }

    # Parse manifest
    $TsvLines = Get-Content $ManifestTsv
    $ProbeEntries = @()
    foreach ($Line in $TsvLines) {
        $Fields = $Line -split "`t"
        if ($Fields.Count -lt 8) { continue }
        if ($Fields[3] -ne "1") { continue }
        $ProbeEntries += [PSCustomObject]@{
            ProbeId  = $Fields[0]
            RelPath  = $Fields[1]
        }
    }

    # Parallel compilation using Start-Job with throttling
    $Jobs = @()
    foreach ($Entry in $ProbeEntries) {
        $Src     = Join-Path $PSScriptRoot ".." "probes" $Entry.RelPath
        $RelBase = $Entry.RelPath -replace '\.cu$', ''
        $Cubin   = Join-Path $Dir "$RelBase.cubin"
        $RegFile = Join-Path $Dir "$RelBase.reg"
        $StatusFile = Join-Path $Dir "$RelBase.status"

        $CubinDir = Split-Path $Cubin -Parent
        if (-not (Test-Path $CubinDir)) {
            New-Item -ItemType Directory -Path $CubinDir -Force | Out-Null
        }

        # Throttle: wait if at capacity
        while (($Jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $SweepJobs) {
            Start-Sleep -Milliseconds 100
        }

        $AllFlags = $BaseFlagArray + $ExtraFlagArray + @("-Xptxas", "-v", "-cubin", $Src, "-o", $Cubin)
        $Job = Start-Job -ScriptBlock {
            param($NvccBin, $FlagList, $RegOut, $StatusOut)
            try {
                & $NvccBin @FlagList 2> $RegOut
                if ($LASTEXITCODE -eq 0) {
                    Set-Content -Path $StatusOut -Value "ok"
                } else {
                    Set-Content -Path $StatusOut -Value "fail"
                }
            }
            catch {
                Set-Content -Path $StatusOut -Value "fail"
            }
        } -ArgumentList $Nvcc, $AllFlags, $RegFile, $StatusFile

        $Jobs += $Job
    }

    # Wait for all compilation jobs
    $Jobs | Wait-Job | Out-Null
    $Jobs | Remove-Job -Force

    # Gather stats
    $Pass = 0; $FailCount = 0; $TotalRegs = 0; $TotalSpills = 0; $MaxRegs = 0
    $SpillKernels = @()

    foreach ($Entry in $ProbeEntries) {
        $RelBase = $Entry.RelPath -replace '\.cu$', ''
        $RegFile = Join-Path $Dir "$RelBase.reg"
        $StatusFile = Join-Path $Dir "$RelBase.status"

        $Status = "fail"
        if (Test-Path $StatusFile) {
            $Status = (Get-Content $StatusFile -Raw).Trim()
        }

        if ($Status -eq "ok") {
            $Pass++
            $Regs = 0; $Spills = 0
            if (Test-Path $RegFile) {
                $RegContent = Get-Content $RegFile -ErrorAction SilentlyContinue
                foreach ($RL in $RegContent) {
                    if ($RL -match 'Used (\d+) registers') {
                        $r = [int]$Matches[1]
                        if ($r -gt $Regs) { $Regs = $r }
                    }
                    if ($RL -match '(\d+) bytes spill stores') {
                        $s = [int]$Matches[1]
                        if ($s -gt $Spills) { $Spills = $s }
                    }
                }
            }
            if ($Regs -gt $MaxRegs) { $MaxRegs = $Regs }
            $TotalRegs += $Regs
            $TotalSpills += $Spills
            if ($Spills -gt 0) {
                $SpillKernels += "$($Entry.ProbeId)($Spills)"
            }
        }
        else {
            $FailCount++
        }
    }

    # Extract mnemonics from cubins in parallel
    $MnemFile = Join-Path $Dir "mnemonics.txt"
    $CubinFiles = Get-ChildItem -Path $Dir -Filter "*.cubin" -Recurse -File -ErrorAction SilentlyContinue

    $ExtractJobs = @()
    foreach ($CubinFile in $CubinFiles) {
        while (($ExtractJobs | Where-Object { $_.State -eq 'Running' }).Count -ge $SweepExtractJobs) {
            Start-Sleep -Milliseconds 100
        }
        $Job = Start-Job -ScriptBlock {
            param($CubinPath, $CuObjDumpBin)
            try {
                & $CuObjDumpBin -sass $CubinPath 2>$null
            }
            catch {}
        } -ArgumentList $CubinFile.FullName, "cuobjdump"
        $ExtractJobs += $Job
    }

    $ExtractJobs | Wait-Job | Out-Null
    $MnemSet = @{}
    foreach ($Job in $ExtractJobs) {
        $Output = Receive-Job $Job
        foreach ($SassLine in $Output) {
            if ($SassLine -match '^\s+/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)') {
                $MnemSet[$Matches[1]] = $true
            }
        }
    }
    $ExtractJobs | Remove-Job -Force

    $MnemSet.Keys | Sort-Object | Set-Content -Path $MnemFile
    $MnemCount = $MnemSet.Count

    # Diff against baseline
    $NewCount = 0
    $NewList = ""
    if (Test-Path $Baseline) {
        $BaselineSet = @{}
        Get-Content $Baseline | ForEach-Object { $BaselineSet[$_] = $true }
        $Novel = $MnemSet.Keys | Where-Object { -not $BaselineSet.ContainsKey($_) } | Sort-Object
        $NewCount = @($Novel).Count
        $NewList = ($Novel -join ' ')
    }

    $CheckedInNewCount = 0
    $CheckedInNewList = ""
    if (Test-Path $CheckedInBaseline) {
        $CiSet = @{}
        Get-Content $CheckedInBaseline | ForEach-Object { $CiSet[$_] = $true }
        $CiNovel = $MnemSet.Keys | Where-Object { -not $CiSet.ContainsKey($_) } | Sort-Object
        $CheckedInNewCount = @($CiNovel).Count
        $CheckedInNewList = ($CiNovel -join ' ')
        if ($CheckedInNewCount -gt 0) {
            $CiNovel | Set-Content -Path (Join-Path $Dir "novel_vs_checked_in.txt")
        }
    }

    $Summary = "{0,-32} pass={1} fail={2} mnem={3} new={4} maxreg={5} spills={6}" -f $Label, $Pass, $FailCount, $MnemCount, $NewCount, $MaxRegs, $TotalSpills
    Log-Sweep $Summary
    if ($SpillKernels.Count -gt 0) {
        Log-Sweep "  SPILLS: $($SpillKernels -join ' ')"
    }
    if ($NewCount -gt 0) {
        Log-Sweep "  NEW: $NewList"
    }
    if ($CheckedInNewCount -gt 0) {
        Log-Sweep "  NOVEL_VS_CHECKED_IN: $CheckedInNewList"
    }
}

# Build baseline
Log-Sweep "Building baseline..."
Invoke-CompileSet -Label "baseline" -ExtraFlags ""
$BaselineMnemSrc = Join-Path $OutputDir "baseline" "mnemonics.txt"
if (Test-Path $BaselineMnemSrc) {
    Copy-Item $BaselineMnemSrc $Baseline
}

Log-Sweep ""
Log-Sweep "=== Canonical Matrix ==="
Invoke-CompileSet -Label "O2"             -ExtraFlags "-O2"
Invoke-CompileSet -Label "O2_xptxas_O3"   -ExtraFlags "-O2 -Xptxas -O3"
Invoke-CompileSet -Label "O3"             -ExtraFlags "-O3"
Invoke-CompileSet -Label "O3_xptxas_O3"   -ExtraFlags "-O3 -Xptxas -O3"
Invoke-CompileSet -Label "G"              -ExtraFlags "-O0 -G"
Invoke-CompileSet -Label "G_xptxas_O3"    -ExtraFlags "-O0 -G -Xptxas -O3"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: Precision/Math ==="
Invoke-CompileSet -Label "fmad_false"  -ExtraFlags "-O2 -fmad=false"
Invoke-CompileSet -Label "prec_div"    -ExtraFlags "-O2 --prec-div=true"
Invoke-CompileSet -Label "prec_sqrt"   -ExtraFlags "-O2 --prec-sqrt=true"
Invoke-CompileSet -Label "ftz_false"   -ExtraFlags "-O2 -ftz=false"
Invoke-CompileSet -Label "fast_math"   -ExtraFlags "-O2 --use_fast_math"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: Register Pressure ==="
Invoke-CompileSet -Label "maxreg32"  -ExtraFlags "-O2 --maxrregcount=32"
Invoke-CompileSet -Label "maxreg64"  -ExtraFlags "-O2 --maxrregcount=64"
Invoke-CompileSet -Label "maxreg128" -ExtraFlags "-O2 --maxrregcount=128"
Invoke-CompileSet -Label "maxreg255" -ExtraFlags "-O2 --maxrregcount=255"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: Special Flags ==="
Invoke-CompileSet -Label "restrict"         -ExtraFlags "-O2 --restrict"
Invoke-CompileSet -Label "per_thread_stream" -ExtraFlags "-O2 --default-stream per-thread"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: Verified Toolchain Knobs ==="
Invoke-CompileSet -Label "G_dopt_on"            -ExtraFlags "-O0 -G -dopt=on"
Invoke-CompileSet -Label "vec"                  -ExtraFlags "-O2 --extra-device-vectorization"
Invoke-CompileSet -Label "vec_restrict"         -ExtraFlags "-O2 --extra-device-vectorization --restrict"
Invoke-CompileSet -Label "fast_vec_restrict"    -ExtraFlags "-O3 --use_fast_math --extra-device-vectorization --restrict"
Invoke-CompileSet -Label "dlcm_cg"             -ExtraFlags "-O2 -Xptxas -dlcm=cg"
Invoke-CompileSet -Label "disable_opt_consts"  -ExtraFlags "-O2 -Xptxas -disable-optimizer-consts"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: Combined ==="
Invoke-CompileSet -Label "O3_prec"          -ExtraFlags "-O3 --prec-div=true --prec-sqrt=true -ftz=false -fmad=false"
Invoke-CompileSet -Label "O3_fast_restrict" -ExtraFlags "-O3 --use_fast_math --restrict"

Log-Sweep ""
Log-Sweep "=== Discovery Delta: PTX Warnings ==="
Invoke-CompileSet -Label "warn_spills"  -ExtraFlags "-O2 -Xptxas -warn-spills,-warn-lmem-usage"
Invoke-CompileSet -Label "warn_double"  -ExtraFlags "-O2 -Xptxas -warn-double-usage"

Log-Sweep ""
Log-Sweep "=== SWEEP COMPLETE ==="
Log-Sweep "Results in: $OutputDir"
Log-Sweep "Full log: $SweepLog"
