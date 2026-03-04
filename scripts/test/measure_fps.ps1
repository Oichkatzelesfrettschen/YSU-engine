# FPS Test with actual timing measurements
# Uses PowerShell Measure-Command to time each test

$exePath = ".\gpu_demo.exe"
$results = @()

Write-Host "====== FPS TIMING TEST ======" -ForegroundColor Cyan
Write-Host ""

# Test function that measures execution time
function Test-Config {
    param(
        [string]$Name,
        [hashtable]$EnvVars
    )
    
    # Set environment
    foreach ($key in $EnvVars.Keys) {
        Set-Item -Path "env:$key" -Value $EnvVars[$key]
    }
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    
    # Measure execution time
    $time = (Measure-Command {
        $output = & $exePath 2>&1 | Out-Null
    }).TotalSeconds
    
    $frames = [int]$EnvVars["YSU_GPU_FRAMES"]
    $fps = [math]::Round($frames / $time, 2)
    
    Write-Host "  Time: $([math]::Round($time, 2))s | FPS: $fps" -ForegroundColor Green
    
    return [PSCustomObject]@{
        Config = $Name
        Frames = $frames
        TotalTime = [math]::Round($time, 2)
        FPS = $fps
    }
}

# Run tests
Write-Host "Resolution: 1920x1080 | 60 frames per test" -ForegroundColor Gray
Write-Host ""

$results += Test-Config "1. Baseline (no denoise)" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "0"
}

$results += Test-Config "2. Denoise skip=1" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "1"
}

$results += Test-Config "3. Denoise skip=2" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "2"
}

$results += Test-Config "4. Denoise skip=4" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "4"
}

$results += Test-Config "5. Denoise skip=8" @{
    "YSU_GPU_W" = "1920"
    "YSU_GPU_H" = "1080"
    "YSU_GPU_FRAMES" = "60"
    "YSU_GPU_DENOISE" = "1"
    "YSU_GPU_DENOISE_SKIP" = "8"
}

# Display results table
Write-Host ""
Write-Host "====== RESULTS ======" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Calculate improvements
$baselineFPS = ($results | Where-Object {$_.Config -eq "1. Baseline (no denoise)"}).FPS
Write-Host "Performance vs Baseline:" -ForegroundColor Cyan
foreach ($result in $results | Select-Object -Skip 1) {
    $improvement = [math]::Round((($result.FPS / $baselineFPS) - 1) * 100, 1)
    $sign = if ($improvement -gt 0) {"+"} else {""}
    Write-Host "  $($result.Config): ${sign}${improvement}% ($($result.FPS) FPS)" -ForegroundColor $(if ($improvement -ge 0) {"Green"} else {"Red"})
}

# Export to CSV
$csvFile = "fps_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $csvFile -NoTypeInformation
Write-Host ""
Write-Host "Results exported to: $csvFile" -ForegroundColor Green
