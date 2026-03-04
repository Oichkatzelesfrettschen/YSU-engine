# Comprehensive FPS Test Suite for Advanced Denoiser Features
# Tests all denoise configurations to establish baseline and measure improvements

$ErrorActionPreference = "Stop"
$exePath = ".\gpu_demo.exe"
$testObject = "TestSubjects/3M.obj"
$timestampedLog = "fps_test_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Verify executable exists
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: gpu_demo.exe not found!" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FPS TEST SUITE - Advanced Denoiser" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Executable: $exePath" -ForegroundColor Green
Write-Host "Test Object: $testObject" -ForegroundColor Green
Write-Host "Results Log: $timestampedLog" -ForegroundColor Green
Write-Host ""

# Helper function to run test and capture FPS
function Run-FPS-Test {
    param(
        [string]$TestName,
        [int]$Frames = 120,
        [hashtable]$EnvVars = @{}
    )
    
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    Write-Host "  Frames: $Frames" -ForegroundColor Gray
    
    # Build env var display
    $envDisplay = @()
    foreach ($key in $EnvVars.Keys | Sort-Object) {
        $val = $EnvVars[$key]
        $envDisplay += "  $key=$val"
    }
    if ($envDisplay.Count -gt 0) {
        Write-Host "  Environment:" -ForegroundColor Gray
        $envDisplay | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    }
    
    # Set environment variables
    $prevEnv = @{}
    foreach ($key in $EnvVars.Keys) {
        $prevEnv[$key] = [System.Environment]::GetEnvironmentVariable($key)
        [System.Environment]::SetEnvironmentVariable($key, $EnvVars[$key])
    }
    
    try {
        # Run test
        $output = & $exePath 2>&1 | Tee-Object -Variable testOutput
        
        # Parse output for FPS or timing information
        $fpsLine = $output | Select-String "FPS|fps|frame.*time|Frame.*Time" | Select-Object -First 1
        
        if ($fpsLine) {
            Write-Host "  Result: $($fpsLine.Line)" -ForegroundColor Green
            Add-Content -Path $timestampedLog -Value "$TestName`n  $($fpsLine.Line)`n"
        } else {
            Write-Host "  Result: Test completed (FPS metric not found in output)" -ForegroundColor Yellow
            Add-Content -Path $timestampedLog -Value "$TestName`n  Test completed`n"
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        Add-Content -Path $timestampedLog -Value "$TestName`n  ERROR: $_`n"
    } finally {
        # Restore environment
        foreach ($key in $prevEnv.Keys) {
            if ($prevEnv[$key]) {
                [System.Environment]::SetEnvironmentVariable($key, $prevEnv[$key])
            } else {
                [System.Environment]::SetEnvironmentVariable($key, "")
            }
        }
    }
    
    Write-Host ""
}

# Initialize log
"FPS TEST RESULTS - Advanced Denoiser Features" | Out-File -FilePath $timestampedLog
"Generated: $(Get-Date)" | Add-Content -Path $timestampedLog
"========================================" | Add-Content -Path $timestampedLog
"" | Add-Content -Path $timestampedLog

# Test 1: Baseline (no denoise)
Write-Host "PHASE 1: Baseline (No Denoise)" -ForegroundColor Magenta
Run-FPS-Test -TestName "1. Baseline (no denoise)" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "0"
}

# Test 2: Denoise enabled, no skip
Write-Host "PHASE 2: Denoise Configurations" -ForegroundColor Magenta
Run-FPS-Test -TestName "2. Denoise enabled (skip=1, every frame)" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "1"
}

# Test 3: Denoise skip=2
Run-FPS-Test -TestName "3. Denoise with skip=2" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "2"
}

# Test 4: Denoise skip=4
Run-FPS-Test -TestName "4. Denoise with skip=4" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
}

# Test 5: Denoise skip=8
Run-FPS-Test -TestName "5. Denoise with skip=8 (aggressive)" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "8"
}

# Test 6: Temporal blend with denoise
Write-Host "PHASE 3: Temporal Integration" -ForegroundColor Magenta
Run-FPS-Test -TestName "6. Denoise + Temporal blend (skip=4)" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
    "YSU_GPU_TEMPORAL_DENOISE" = "1"
    "YSU_GPU_TEMPORAL_DENOISE_WEIGHT" = "0.8"
}

# Test 7: History reset enabled (requires recompile)
Write-Host "PHASE 4: Advanced Features (Post-Compile)" -ForegroundColor Magenta
Run-FPS-Test -TestName "7. Denoise + History reset (every 60 frames)" -Frames 300 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "300"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
    "YSU_GPU_DENOISE_HISTORY_RESET" = "1"
    "YSU_GPU_DENOISE_HISTORY_RESET_FRAME" = "60"
}

# Test 8: Adaptive denoise (requires recompile)
Run-FPS-Test -TestName "8. Denoise + Adaptive (warmup 30f, steady-state 8x)" -Frames 120 -EnvVars @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_OBJ" = $testObject
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MIN" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MAX" = "8"
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All tests completed!" -ForegroundColor Green
Write-Host "Results saved to: $timestampedLog" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: Tests 7 & 8 require recompilation with Vulkan SDK" -ForegroundColor Yellow
Write-Host "Current executable may not have History Reset & Adaptive features" -ForegroundColor Yellow
