<#
.SYNOPSIS
  Smoke-test a representative recursive subset through 6 canonical lanes + ncu.

.DESCRIPTION
  Compiles a small representative set of probes through 6 flag lanes
  (O2, O2_xptxas_O3, O3, O3_xptxas_O3, G, G_xptxas_O3), extracts
  mnemonics per lane, builds and runs targeted runners, and profiles
  selected kernels with Nsight Compute.

.PARAMETER OutputDir
  Directory for results (default: results/runs/smoke_recursive_<timestamp>).

.NOTES
  Equivalent of smoke_recursive_subset.sh.
  Requires: nvcc, cuobjdump, ncu, python3
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$NvccStdFlag = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "resolve_nvcc_std_flag.ps1") -NvccBin $Nvcc

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "runs" "smoke_recursive_$Timestamp"
}

$LanesDir = Join-Path $OutputDir "lanes"
$DisasmDir = Join-Path $OutputDir "disasm"
$LogsDir  = Join-Path $OutputDir "logs"
$NcuDir   = Join-Path $OutputDir "ncu"

New-Item -ItemType Directory -Path $LanesDir -Force | Out-Null
New-Item -ItemType Directory -Path $DisasmDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
New-Item -ItemType Directory -Path $NcuDir -Force | Out-Null

$CompileStatusCsv = Join-Path $LanesDir "compile_status.csv"
Set-Content -Path $CompileStatusCsv -Value "lane,probe,status"

$NcuStatusCsv = Join-Path $NcuDir "ncu_status.csv"
Set-Content -Path $NcuStatusCsv -Value "target,status,csv_lines"

$BaseFlags = @("-arch=sm_89") + ($NvccStdFlag -split '\s+') + @("-lineinfo")

# ncu helper
function Invoke-NcuProfile {
    param(
        [string]$Label,
        [string]$CsvPath,
        [string]$LogPath,
        [string[]]$Command
    )
    try {
        & $Command[0] $Command[1..($Command.Count - 1)] > $CsvPath 2> $LogPath
        if ($LASTEXITCODE -eq 0) {
            $Lines = (Get-Content $CsvPath | Measure-Object -Line).Lines
            Add-Content -Path $NcuStatusCsv -Value "$Label,OK,$Lines"
        } else {
            Add-Content -Path $NcuStatusCsv -Value "$Label,FAIL_$LASTEXITCODE,0"
            Set-Content -Path $CsvPath -Value ""
        }
    }
    catch {
        Add-Content -Path $NcuStatusCsv -Value "$Label,FAIL,0"
        Set-Content -Path $CsvPath -Value ""
    }
}

$LaneConfigs = @{
    "O2"             = "-O2"
    "O2_xptxas_O3"   = "-O2 -Xptxas -O3"
    "O3"             = "-O3"
    "O3_xptxas_O3"   = "-O3 -Xptxas -O3"
    "G"              = "-O0 -G"
    "G_xptxas_O3"    = "-O0 -G -Xptxas -O3"
}

$RepresentativeProbes = @(
    "probe_fp32_arith.cu",
    "atomic_sweep/probe_redux_all_ops.cu",
    "barrier_sync2/probe_bar_red_predicate.cu",
    "atomic_sweep/probe_dp4a_signedness.cu",
    "data_movement/probe_cp_async_zfill.cu",
    "texture_surface/probe_tmu_behavior.cu"
)

foreach ($LaneName in @("O2", "O2_xptxas_O3", "O3", "O3_xptxas_O3", "G", "G_xptxas_O3")) {
    $LaneFlags = ($LaneConfigs[$LaneName]) -split '\s+'
    $LaneDir = Join-Path $LanesDir $LaneName
    New-Item -ItemType Directory -Path $LaneDir -Force | Out-Null

    foreach ($Rel in $RepresentativeProbes) {
        $Src     = Join-Path $PSScriptRoot ".." "probes" $Rel
        $Base    = $Rel -replace '\.cu$', ''
        $Cubin   = Join-Path $LaneDir "$Base.cubin"
        $Sass    = Join-Path $LaneDir "$Base.sass"
        $RegFile = Join-Path $LaneDir "$Base.reg"

        $CubinDir = Split-Path $Cubin -Parent
        if (-not (Test-Path $CubinDir)) {
            New-Item -ItemType Directory -Path $CubinDir -Force | Out-Null
        }

        $AllFlags = $BaseFlags + $LaneFlags + @("-Xptxas", "-v", "-cubin", $Src, "-o", $Cubin)
        & $Nvcc @AllFlags 2> $RegFile
        if ($LASTEXITCODE -eq 0) {
            & cuobjdump -sass $Cubin > $Sass 2>$null
            Add-Content -Path $CompileStatusCsv -Value "$LaneName,$Rel,OK"
        } else {
            Add-Content -Path $CompileStatusCsv -Value "$LaneName,$Rel,COMPILE_FAIL"
        }
    }

    # Extract mnemonics for this lane
    $MnemFile = Join-Path $LaneDir "mnemonics.txt"
    $MnemSet = @{}
    $SassFiles = Get-ChildItem -Path $LaneDir -Filter "*.sass" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($SF in $SassFiles) {
        $Content = Get-Content $SF.FullName -ErrorAction SilentlyContinue
        foreach ($SLine in $Content) {
            if ($SLine -match '^\s+/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)') {
                $MnemSet[$Matches[1]] = $true
            }
        }
    }
    $MnemSet.Keys | Sort-Object | Set-Content -Path $MnemFile
}

# Mnemonic hunt across lanes
$MnemHuntPy = Join-Path $PSScriptRoot "mnemonic_hunt.py"
$MnemArgs = @("O2", "O2_xptxas_O3", "O3", "O3_xptxas_O3", "G", "G_xptxas_O3") |
    ForEach-Object { Join-Path $LanesDir $_ "mnemonics.txt" }
& python3 $MnemHuntPy @MnemArgs > (Join-Path $LanesDir "novel_vs_checked_in.txt")

# Build and run targeted runners
Write-Host "Building targeted runners..." -ForegroundColor Yellow

& $Nvcc -arch=sm_89 $NvccStdFlag (Join-Path $PSScriptRoot ".." "runners" "dp4a_signedness_runner.cu") -o (Join-Path $LogsDir "dp4a_runner.exe")
& (Join-Path $LogsDir "dp4a_runner.exe") > (Join-Path $LogsDir "dp4a_runner.txt") 2>&1

& $Nvcc -arch=sm_89 $NvccStdFlag (Join-Path $PSScriptRoot ".." "runners" "cp_async_zfill_runner.cu") -o (Join-Path $LogsDir "cp_async_runner.exe")
& (Join-Path $LogsDir "cp_async_runner.exe") > (Join-Path $LogsDir "cp_async_runner.txt") 2>&1

& $Nvcc -arch=sm_89 $NvccStdFlag (Join-Path $PSScriptRoot ".." "runners" "texture_surface_runner.cu") -o (Join-Path $LogsDir "texture_runner.exe")
& (Join-Path $LogsDir "texture_runner.exe") probe_tmu_behavior > (Join-Path $LogsDir "texture_tmu_behavior.txt") 2>&1

# Build ncu runner harnesses
& python3 (Join-Path $PSScriptRoot "probe_manifest.py") generate-runner --probe "atomic_sweep/probe_redux_all_ops.cu" --output (Join-Path $NcuDir "redux_runner.cu")
& $Nvcc -arch=sm_89 $NvccStdFlag (Join-Path $NcuDir "redux_runner.cu") -o (Join-Path $NcuDir "redux_runner.exe")

& python3 (Join-Path $PSScriptRoot "probe_manifest.py") generate-runner --probe "barrier_sync2/probe_bar_red_predicate.cu" --output (Join-Path $NcuDir "bar_red_runner.cu")
& $Nvcc -arch=sm_89 $NvccStdFlag (Join-Path $NcuDir "bar_red_runner.cu") -o (Join-Path $NcuDir "bar_red_runner.exe")

# Profile with ncu
$NcuMetrics = "smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum"
$NcuBaseOpts = @("--metrics", $NcuMetrics, "--csv", "--target-processes", "all")

Invoke-NcuProfile -Label "dp4a" `
    -CsvPath (Join-Path $NcuDir "dp4a.csv") `
    -LogPath (Join-Path $NcuDir "dp4a.log") `
    -Command @("ncu") + $NcuBaseOpts + @((Join-Path $LogsDir "dp4a_runner.exe"))

Invoke-NcuProfile -Label "cp_async" `
    -CsvPath (Join-Path $NcuDir "cp_async.csv") `
    -LogPath (Join-Path $NcuDir "cp_async.log") `
    -Command @("ncu") + $NcuBaseOpts + @((Join-Path $LogsDir "cp_async_runner.exe"), "--profile-safe")

Invoke-NcuProfile -Label "redux" `
    -CsvPath (Join-Path $NcuDir "redux.csv") `
    -LogPath (Join-Path $NcuDir "redux.log") `
    -Command @("ncu") + $NcuBaseOpts + @((Join-Path $NcuDir "redux_runner.exe"))

Invoke-NcuProfile -Label "bar_red" `
    -CsvPath (Join-Path $NcuDir "bar_red.csv") `
    -LogPath (Join-Path $NcuDir "bar_red.log") `
    -Command @("ncu") + $NcuBaseOpts + @((Join-Path $NcuDir "bar_red_runner.exe"))

Invoke-NcuProfile -Label "texture_tmu_behavior_full" `
    -CsvPath (Join-Path $NcuDir "texture_tmu_behavior_full.csv") `
    -LogPath (Join-Path $NcuDir "texture_tmu_behavior_full.log") `
    -Command @("ncu", "--set", "full", "--csv", "--target-processes", "all", (Join-Path $LogsDir "texture_runner.exe"), "probe_tmu_behavior")

Write-Host "Smoke artifacts: $OutputDir" -ForegroundColor Cyan
