# Advanced Features FPS Test - Tests new History Reset and Adaptive Denoise
$exePath = ".\gpu_demo.exe"
$results = @()

Write-Host "====== ADVANCED FEATURES TEST ======" -ForegroundColor Cyan
Write-Host ""

function Test-Config {
    param(
        [string]$Name,
        [hashtable]$EnvVars,
        [int]$Frames = 60
    )
    
    foreach ($key in $EnvVars.Keys) {
        Set-Item -Path "env:$key" -Value $EnvVars[$key]
    }
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    
    $time = (Measure-Command {
        $output = & $exePath 2>&1 | Out-Null
    }).TotalSeconds
    
    $fps = [math]::Round($Frames / $time, 2)
    
    Write-Host "  Time: $([math]::Round($time, 2))s | FPS: $fps" -ForegroundColor Green
    
    return [PSCustomObject]@{
        Config = $Name
        Frames = $Frames
        TotalTime = [math]::Round($time, 2)
        FPS = $fps
    }
}

Write-Host "Resolution: 1920x1080" -ForegroundColor Gray
Write-Host ""

# Baseline for comparison
$results += Test-Config "1. Baseline (no denoise)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "0"
} -Frames 60

# Denoise with skip=4 (optimal from previous test)
$results += Test-Config "2. Denoise skip=4" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
} -Frames 60

# History Reset enabled (longer test)
$results += Test-Config "3. Denoise skip=4 + History Reset" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "180"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
    "YSU_GPU_DENOISE_HISTORY_RESET" = "1"
    "YSU_GPU_DENOISE_HISTORY_RESET_FRAME" = "60"
} -Frames 180

# Adaptive Denoise (120 frames to see warmup + steady state)
$results += Test-Config "4. Adaptive Denoise (warmup->sparse)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MIN" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MAX" = "8"
} -Frames 120

# Full stack: skip=4 + history reset + adaptive
$results += Test-Config "5. Full Stack (skip=4 + reset + adaptive)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
    "YSU_GPU_DENOISE_ADAPTIVE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MIN" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MAX" = "8"
    "YSU_GPU_DENOISE_HISTORY_RESET" = "1"
    "YSU_GPU_DENOISE_HISTORY_RESET_FRAME" = "60"
} -Frames 120

Write-Host ""
Write-Host "====== RESULTS ======" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Calculate normalized FPS (FPS per 60 frames)
Write-Host "Performance Analysis:" -ForegroundColor Cyan
foreach ($result in $results) {
    $normalizedFPS = [math]::Round(($result.FPS * 60) / $result.Frames, 2)
    Write-Host "  $($result.Config): $normalizedFPS FPS (60-frame equivalent)" -ForegroundColor Green
}

# Export
$csvFile = "fps_advanced_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $csvFile -NoTypeInformation
Write-Host ""
Write-Host "Results exported to: $csvFile" -ForegroundColor Green
