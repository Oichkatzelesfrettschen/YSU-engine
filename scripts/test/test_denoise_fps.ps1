
# Simple FPS test - runs denoise configurations on GPU renderer
$exePath = ".\gpu_demo.exe"
$outputLog = "fps_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host "====== GPU DENOISE FPS TEST ======" -ForegroundColor Cyan
Write-Host "Executable: $exePath" -ForegroundColor Green
Write-Host "Results: $outputLog" -ForegroundColor Green
Write-Host ""

Add-Content $outputLog "GPU Denoise FPS Test"
Add-Content $outputLog "===================="
Add-Content $outputLog "Timestamp: $(Get-Date)"
Add-Content $outputLog ""

# Test 1: Baseline
Write-Host "[1/5] Running Baseline (no denoise)..." -ForegroundColor Yellow
$env:YSU_GPU_FRAMES = "60"
$env:YSU_GPU_DENOISE = "0"
$result1 = & $exePath 2>&1 | Out-String
Add-Content $outputLog "Test 1: Baseline (no denoise)"
Add-Content $outputLog $result1
Add-Content $outputLog ""
Write-Host "      Completed" -ForegroundColor Green

# Test 2: Denoise skip=1
Write-Host "[2/5] Running Denoise (skip=1, every frame)..." -ForegroundColor Yellow
$env:YSU_GPU_FRAMES = "60"
$env:YSU_GPU_DENOISE = "1"
$env:YSU_GPU_DENOISE_SKIP = "1"
$result2 = & $exePath 2>&1 | Out-String
Add-Content $outputLog "Test 2: Denoise (skip=1)"
Add-Content $outputLog $result2
Add-Content $outputLog ""
Write-Host "      Completed" -ForegroundColor Green

# Test 3: Denoise skip=2
Write-Host "[3/5] Running Denoise (skip=2)..." -ForegroundColor Yellow
$env:YSU_GPU_FRAMES = "60"
$env:YSU_GPU_DENOISE = "1"
$env:YSU_GPU_DENOISE_SKIP = "2"
$result3 = & $exePath 2>&1 | Out-String
Add-Content $outputLog "Test 3: Denoise (skip=2)"
Add-Content $outputLog $result3
Add-Content $outputLog ""
Write-Host "      Completed" -ForegroundColor Green

# Test 4: Denoise skip=4
Write-Host "[4/5] Running Denoise (skip=4)..." -ForegroundColor Yellow
$env:YSU_GPU_FRAMES = "60"
$env:YSU_GPU_DENOISE = "1"
$env:YSU_GPU_DENOISE_SKIP = "4"
$result4 = & $exePath 2>&1 | Out-String
Add-Content $outputLog "Test 4: Denoise (skip=4)"
Add-Content $outputLog $result4
Add-Content $outputLog ""
Write-Host "      Completed" -ForegroundColor Green

# Test 5: Denoise skip=8
Write-Host "[5/5] Running Denoise (skip=8)..." -ForegroundColor Yellow
$env:YSU_GPU_FRAMES = "60"
$env:YSU_GPU_DENOISE = "1"
$env:YSU_GPU_DENOISE_SKIP = "8"
$result5 = & $exePath 2>&1 | Out-String
Add-Content $outputLog "Test 5: Denoise (skip=8)"
Add-Content $outputLog $result5
Add-Content $outputLog ""
Write-Host "      Completed" -ForegroundColor Green

Write-Host ""
Write-Host "====== ALL TESTS COMPLETED ======" -ForegroundColor Cyan
Write-Host "Results saved to: $outputLog" -ForegroundColor Green
Write-Host ""

# Display summary from log
Write-Host "Summary from results:" -ForegroundColor Cyan
Select-String "^Test \d:|Counters:|wrote output" $outputLog | ForEach-Object { Write-Host $_.Line }
