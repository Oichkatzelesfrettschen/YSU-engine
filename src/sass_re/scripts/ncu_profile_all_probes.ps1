<#
.SYNOPSIS
  Profile the recursive probe corpus with Nsight Compute.

.DESCRIPTION
  Plain probes use a targeted metric set to avoid replay explosion.
  Texture/surface probes use a dedicated host runner and --set full.
  Handles different runner_kind cases (texture_surface, cp_async_zfill,
  mbarrier, barrier_arrive_wait, barrier_coop_groups, cooperative_launch,
  tiling_hierarchical, depbar_explicit, optix_pipeline, optix_callable_pipeline,
  optical_flow, video_codec, cudnn).

.PARAMETER OutputDir
  Directory for results (default: results/runs/ncu_full_<timestamp>).

.NOTES
  Equivalent of ncu_profile_all_probes.sh.
  Requires: ncu, nvcc, cuobjdump, python3
#>

param(
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

$Ncu  = if ($env:NCU)  { $env:NCU }  else { "ncu" }
$Nvcc = if ($env:NVCC) { $env:NVCC } else { "nvcc" }
$Arch = "sm_89"
$NvccStdFlag = & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "resolve_nvcc_std_flag.ps1") -NvccBin $Nvcc
$ManifestPy = Join-Path $PSScriptRoot "probe_manifest.py"
$RunnerDir  = Join-Path $PSScriptRoot ".." "runners"
$KeepRunnerArtifacts = if ($env:KEEP_RUNNER_ARTIFACTS -eq "1") { $true } else { $false }

if (-not $OutputDir) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $PSScriptRoot ".." "results" "runs" "ncu_full_$Timestamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$GeneralMetrics = "smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum"
$GeneralOpts = @("--metrics", $GeneralMetrics, "--csv", "--target-processes", "all")
$TmuOpts     = @("--set", "full", "--csv", "--target-processes", "all")

$ManifestTsv = Join-Path $OutputDir "probe_manifest.tsv"
& python3 $ManifestPy emit --format tsv > $ManifestTsv

# Metric preflight
$PreflightCsv = Join-Path $OutputDir "metric_preflight.csv"
Set-Content -Path $PreflightCsv -Value "metric,status"
foreach ($Metric in @("smsp__inst_executed.sum", "smsp__warp_active.avg", "l1tex__t_bytes.sum", "dram__bytes.sum")) {
    try {
        $QueryOutput = & $Ncu --query-metrics 2>&1 | Out-String
        if ($QueryOutput -match [regex]::Escape($Metric)) {
            Add-Content -Path $PreflightCsv -Value "$Metric,OK"
        } else {
            Add-Content -Path $PreflightCsv -Value "$Metric,MISSING"
        }
    }
    catch {
        Add-Content -Path $PreflightCsv -Value "$Metric,MISSING"
    }
}

$Pass = 0
$Fail = 0
$Skip = 0

Write-Host "=== ncu Full Profile: All Probes ===" -ForegroundColor Cyan
Write-Host "Output: $OutputDir"
Write-Host ""

$ExpectedSkipProbes = @(
    "probe_optix_rt_core.cu",
    "probe_uniform_ushf_u64_hi_final.cu"
)

function Remove-RunnerArtifacts {
    param([string[]]$Paths)
    if ($KeepRunnerArtifacts) { return }
    foreach ($P in $Paths) {
        Remove-Item -Path $P -Force -ErrorAction SilentlyContinue
    }
}

# Define specialized runner kinds that get profile_enabled=1
$SpecialRunnerKinds = @(
    "texture_surface", "cp_async_zfill", "mbarrier", "barrier_arrive_wait",
    "barrier_coop_groups", "cooperative_launch", "tiling_hierarchical",
    "depbar_explicit", "optix_pipeline", "optix_callable_pipeline",
    "optical_flow", "video_codec", "cudnn"
)

$TsvLines = Get-Content $ManifestTsv
foreach ($Line in $TsvLines) {
    $Fields = $Line -split "`t"
    if ($Fields.Count -lt 8) { continue }

    $ProbeId         = $Fields[0]
    $RelPath         = $Fields[1]
    $CompileEnabled  = $Fields[3]
    $RunnerKind      = $Fields[4]
    $SupportsGeneric = $Fields[5]
    $KernelNames     = $Fields[6]

    $ProfileEnabled = $SpecialRunnerKinds -contains $RunnerKind
    if ($CompileEnabled -ne "1" -and -not $ProfileEnabled) { continue }

    $ProbeOut   = Join-Path $OutputDir ($RelPath -replace '\.cu$', '')
    New-Item -ItemType Directory -Path $ProbeOut -Force | Out-Null

    $Runner     = Join-Path $ProbeOut "${ProbeId}_runner.cu"
    $Binary     = Join-Path $ProbeOut "${ProbeId}_runner.exe"
    $CsvFile    = Join-Path $ProbeOut "${ProbeId}_ncu.csv"
    $CompileLog = Join-Path $ProbeOut "${ProbeId}_compile.log"
    $NcuLog     = Join-Path $ProbeOut "${ProbeId}_ncu.log"
    $Metadata   = Join-Path $ProbeOut "${ProbeId}_metadata.txt"

    $PaddedPath = $RelPath.PadRight(56)
    Write-Host -NoNewline "$PaddedPath "

    Set-Content -Path $Metadata -Value @(
        "probe_id=$ProbeId",
        "relative_path=$RelPath",
        "runner_kind=$RunnerKind",
        "kernel_names=$KernelNames"
    )

    # Check expected-skip probes
    if ($ExpectedSkipProbes -contains $RelPath) {
        Write-Host "EXPECTED SKIP" -ForegroundColor DarkYellow
        Add-Content -Path $Metadata -Value "status=EXPECTED_SKIP"
        $Skip++
        continue
    }

    # Helper: compile a runner and profile it
    function Invoke-RunnerProfile {
        param(
            [string]$RunnerLabel,
            [string]$RunnerBinary,
            [string]$RunnerSrc,
            [string[]]$ExtraNvccArgs,
            [string[]]$NcuArgs,
            [string[]]$BinaryArgs,
            [switch]$UseTmuOpts
        )

        $NvccArgs = @("-arch=$Arch", "-O3", $NvccStdFlag, "-lineinfo") + $ExtraNvccArgs + @("-o", $RunnerBinary, $RunnerSrc)
        & $Nvcc @NvccArgs 2> $CompileLog
        if ($LASTEXITCODE -ne 0) { return "COMPILE" }

        $ProfileOpts = if ($UseTmuOpts) { $TmuOpts } else { $GeneralOpts }
        $FullNcuArgs = $ProfileOpts + $NcuArgs + @($RunnerBinary) + $BinaryArgs
        & $Ncu @FullNcuArgs > $CsvFile 2> $NcuLog
        if ($LASTEXITCODE -ne 0) { return "NCU" }

        return "OK"
    }

    $Handled = $false

    # texture_surface
    if ($RunnerKind -eq "texture_surface") {
        $Binary = Join-Path $ProbeOut "texture_surface_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir "texture_surface_runner.cu"
        $ProbeSelector = [System.IO.Path]::GetFileNameWithoutExtension($RelPath)
        $Result = Invoke-RunnerProfile -RunnerLabel "TMU" -RunnerBinary $Binary -RunnerSrc $RunnerSrc -NcuArgs @() -BinaryArgs @($ProbeSelector) -UseTmuOpts
        if ($Result -eq "OK") {
            $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
            Write-Host "OK TMU ($CsvLines CSV lines)" -ForegroundColor Green
            Remove-RunnerArtifacts @($Binary)
            $Pass++
        } elseif ($Result -eq "COMPILE") {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        } else {
            Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
        }
        continue
    }

    # cp_async_zfill
    if ($RunnerKind -eq "cp_async_zfill") {
        $Binary = Join-Path $ProbeOut "cp_async_zfill_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir "cp_async_zfill_runner.cu"
        $Result = Invoke-RunnerProfile -RunnerLabel "cp.async" -RunnerBinary $Binary -RunnerSrc $RunnerSrc -NcuArgs @() -BinaryArgs @("--profile-safe")
        if ($Result -eq "OK") {
            $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
            Write-Host "OK cp.async ($CsvLines CSV lines)" -ForegroundColor Green
            Remove-RunnerArtifacts @($Binary)
            $Pass++
        } elseif ($Result -eq "COMPILE") {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        } else {
            Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
        }
        continue
    }

    # Simple runner kinds with dedicated runner sources
    $SimpleRunners = @{
        "mbarrier"             = @{ Src = "mbarrier_runner.cu";             Label = "mbarrier" }
        "barrier_arrive_wait"  = @{ Src = "barrier_arrive_wait_runner.cu";  Label = "barrier-arrive" }
        "barrier_coop_groups"  = @{ Src = "barrier_coop_groups_runner.cu";  Label = "barrier-cg" }
        "tiling_hierarchical"  = @{ Src = "tiling_hierarchical_runner.cu";  Label = "tiling-hier" }
        "cooperative_launch"   = @{ Src = "cooperative_launch_runner.cu";   Label = "cooperative-launch" }
        "depbar_explicit"      = @{ Src = "depbar_explicit_runner.cu";      Label = "depbar-explicit" }
    }

    if ($SimpleRunners.ContainsKey($RunnerKind)) {
        $Info = $SimpleRunners[$RunnerKind]
        $Binary = Join-Path $ProbeOut "${RunnerKind}_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir $Info.Src
        $Result = Invoke-RunnerProfile -RunnerLabel $Info.Label -RunnerBinary $Binary -RunnerSrc $RunnerSrc -NcuArgs @() -BinaryArgs @()
        if ($Result -eq "OK") {
            $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
            Write-Host "OK $($Info.Label) ($CsvLines CSV lines)" -ForegroundColor Green
            Remove-RunnerArtifacts @($Binary)
            $Pass++
        } elseif ($Result -eq "COMPILE") {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        } else {
            Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
        }
        continue
    }

    # optix_pipeline
    if ($RunnerKind -eq "optix_pipeline") {
        $BuildScript = Join-Path $PSScriptRoot "build_optix_real_pipeline.sh"
        $Ptx    = Join-Path $ProbeOut "optix_real_pipeline_device.ptx"
        $Binary = Join-Path $ProbeOut "optix_real_pipeline_runner.exe"
        & sh $BuildScript $Ptx $Binary > $CompileLog 2>&1
        if ($LASTEXITCODE -eq 0) {
            & $Ncu @TmuOpts $Binary $Ptx > $CsvFile 2> $NcuLog
            if ($LASTEXITCODE -eq 0) {
                $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
                Write-Host "OK OptiX ($CsvLines CSV lines)" -ForegroundColor Green
                Remove-RunnerArtifacts @($Binary, $Ptx)
                $Pass++
            } else {
                Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
            }
        } else {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        }
        continue
    }

    # optix_callable_pipeline
    if ($RunnerKind -eq "optix_callable_pipeline") {
        $BuildScript = Join-Path $PSScriptRoot "build_optix_callable_pipeline.sh"
        $Ptx    = Join-Path $ProbeOut "optix_callable_pipeline_device.ptx"
        $Binary = Join-Path $ProbeOut "optix_callable_pipeline_runner.exe"
        & sh $BuildScript $Ptx $Binary > $CompileLog 2>&1
        if ($LASTEXITCODE -eq 0) {
            & $Ncu @TmuOpts $Binary $Ptx > $CsvFile 2> $NcuLog
            if ($LASTEXITCODE -eq 0) {
                $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
                Write-Host "OK OptiX-callable ($CsvLines CSV lines)" -ForegroundColor Green
                Remove-RunnerArtifacts @($Binary, $Ptx)
                $Pass++
            } else {
                Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
            }
        } else {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        }
        continue
    }

    # optical_flow
    if ($RunnerKind -eq "optical_flow") {
        $Binary = Join-Path $ProbeOut "ofa_pipeline_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir "ofa_pipeline_runner.cu"
        $NvccArgs = @("-arch=$Arch", "-O3", $NvccStdFlag, "-lineinfo",
                      "-I/usr/include/nvidia", "-I/usr/include/nvidia/opticalflow",
                      "-o", $Binary, $RunnerSrc,
                      "-lcuda", "-lnvidia-opticalflow")
        & $Nvcc @NvccArgs 2> $CompileLog
        if ($LASTEXITCODE -eq 0) {
            & $Ncu @TmuOpts $Binary > $CsvFile 2> $NcuLog
            if ($LASTEXITCODE -eq 0) {
                $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
                Write-Host "OK OFA ($CsvLines CSV lines)" -ForegroundColor Green
                Remove-RunnerArtifacts @($Binary)
                $Pass++
            } else {
                Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
            }
        } else {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        }
        continue
    }

    # video_codec
    if ($RunnerKind -eq "video_codec") {
        $Binary = Join-Path $ProbeOut "nvenc_nvdec_pipeline_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir "nvenc_nvdec_pipeline_runner.cu"
        $NvccArgs = @("-arch=$Arch", "-O3", $NvccStdFlag, "-lineinfo",
                      "-I/usr/include/nvidia-sdk",
                      "-o", $Binary, $RunnerSrc,
                      "-lcuda", "-lnvidia-encode", "-lnvcuvid")
        & $Nvcc @NvccArgs 2> $CompileLog
        if ($LASTEXITCODE -eq 0) {
            & $Ncu @TmuOpts $Binary > $CsvFile 2> $NcuLog
            if ($LASTEXITCODE -eq 0) {
                $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
                Write-Host "OK video ($CsvLines CSV lines)" -ForegroundColor Green
                Remove-RunnerArtifacts @($Binary)
                $Pass++
            } else {
                Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
            }
        } else {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        }
        continue
    }

    # cudnn
    if ($RunnerKind -eq "cudnn") {
        $Binary = Join-Path $ProbeOut "cudnn_conv_mining_runner.exe"
        $RunnerSrc = Join-Path $RunnerDir "cudnn_conv_mining_runner.cu"
        $NvccArgs = @("-arch=$Arch", "-O3", $NvccStdFlag, "-lineinfo",
                      "-o", $Binary, $RunnerSrc,
                      "-lcudnn", "-lcudnn_cnn", "-lcudnn_ops")
        & $Nvcc @NvccArgs 2> $CompileLog
        if ($LASTEXITCODE -eq 0) {
            & $Ncu @GeneralOpts $Binary > $CsvFile 2> $NcuLog
            if ($LASTEXITCODE -eq 0) {
                $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
                Write-Host "OK cuDNN ($CsvLines CSV lines)" -ForegroundColor Green
                Remove-RunnerArtifacts @($Binary)
                $Pass++
            } else {
                Write-Host "ncu FAIL" -ForegroundColor Red; $Fail++
            }
        } else {
            Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow; $Skip++
        }
        continue
    }

    # Generic runner fallback
    if ($SupportsGeneric -ne "1") {
        Write-Host "UNSUPPORTED RUNNER" -ForegroundColor DarkYellow
        Add-Content -Path $Metadata -Value "status=UNSUPPORTED_RUNNER"
        $Skip++
        continue
    }

    & python3 $ManifestPy generate-runner --probe $RelPath --output $Runner
    & $Nvcc "-arch=$Arch" -O3 $NvccStdFlag -lineinfo -o $Binary $Runner 2> $CompileLog
    if ($LASTEXITCODE -eq 0) {
        & $Ncu @GeneralOpts $Binary > $CsvFile 2> $NcuLog
        if ($LASTEXITCODE -eq 0) {
            $CsvLines = (Get-Content $CsvFile | Measure-Object -Line).Lines
            Write-Host "OK ($CsvLines CSV lines)" -ForegroundColor Green
            Remove-RunnerArtifacts @($Runner, $Binary)
            $Pass++
        } else {
            Write-Host "ncu FAIL" -ForegroundColor Red
            $Fail++
        }
    } else {
        Write-Host "COMPILE SKIP" -ForegroundColor DarkYellow
        $Skip++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Profiled: $Pass  Failed: $Fail  Skipped: $Skip  Total: $($Pass + $Fail + $Skip)"
Write-Host "Results:  $OutputDir/"
Write-Host ""
Write-Host "Targeted metrics: $GeneralMetrics"
