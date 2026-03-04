# FPS Test with Animated Camera - Measures performance under movement
# Tests skip=8 configuration with moving camera to validate temporal coherence

$exePath = ".\gpu_demo.exe"
$results = @()

Write-Host "====== FPS TEST WITH ANIMATED CAMERA ======" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scene: Orbiting camera around cube (200 frames per orbit)" -ForegroundColor Gray
Write-Host "Resolution: 1920x1080" -ForegroundColor Gray
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
        FrameTime_ms = [math]::Round(($time * 1000.0) / $Frames, 3)
    }
}

# Test 1: Baseline with animation (no denoise)
$results += Test-Config "1. Animated baseline (no denoise)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "240"
    "YSU_GPU_DENOISE" = "0"
} -Frames 240

# Test 2: Static baseline (for comparison)
$results += Test-Config "2. Static baseline (no denoise)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "0"
} -Frames 60

# Test 3: Animated with skip=8
$results += Test-Config "3. Animated skip=8 (240 frames)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "240"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "8"
} -Frames 240

# Test 4: Long animated skip=8 (6 full orbits for quality validation)
$results += Test-Config "4. Animated skip=8 (360 frames - 6 orbits)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "360"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "8"
} -Frames 360

# Test 5: Animated adaptive denoise
$results += Test-Config "5. Animated adaptive (warmup→sparse)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "120"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MIN" = "1"
    "YSU_GPU_DENOISE_ADAPTIVE_MAX" = "8"
} -Frames 120

Write-Host ""
Write-Host "====== RESULTS TABLE ======" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host ""
Write-Host "====== ANALYSIS ======" -ForegroundColor Cyan

# Compare animated vs static baseline
$animatedBaseline = ($results | Where-Object {$_.Config -match "Animated baseline"}).FPS
$staticBaseline = ($results | Where-Object {$_.Config -match "Static baseline"}).FPS
$animationCost = [math]::Round((1 - ($animatedBaseline / $staticBaseline)) * 100, 1)

Write-Host "Camera Movement Cost: ${animationCost}%" -ForegroundColor $(if ($animationCost -lt 10) {"Green"} else {"Yellow"})
Write-Host "  Static: $staticBaseline FPS vs Animated: $animatedBaseline FPS" -ForegroundColor Gray

# Check skip=8 under movement
$skip8Animated = ($results | Where-Object {$_.Config -match "skip=8 \(240"}).FPS
$skip8Improvement = [math]::Round((($skip8Animated / $animatedBaseline) - 1) * 100, 1)
Write-Host ""
Write-Host "Skip=8 Performance (animated): $skip8Animated FPS (+${skip8Improvement}% vs baseline)" -ForegroundColor Green

# Temporal coherence check (240 vs 360 frames should have similar FPS)
$skip8_240 = ($results | Where-Object {$_.Config -match "skip=8 \(240"}).FPS
$skip8_360 = ($results | Where-Object {$_.Config -match "skip=8 \(360"}).FPS
$coherenceDiff = [math]::Round(((($skip8_240 - $skip8_360) / $skip8_240) * 100), 1)

Write-Host ""
Write-Host "Temporal Coherence (240 vs 360 frames):" -ForegroundColor Cyan
Write-Host "  240 frames: $skip8_240 FPS" -ForegroundColor Green
Write-Host "  360 frames: $skip8_360 FPS" -ForegroundColor Green
Write-Host "  Difference: ${coherenceDiff}% (should be <5% for good coherence)" -ForegroundColor $(if ([math]::Abs($coherenceDiff) -lt 5) {"Green"} else {"Yellow"})

# Export results
$csvFile = "fps_animated_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $csvFile -NoTypeInformation
Write-Host ""
Write-Host "Results exported to: $csvFile" -ForegroundColor Green
