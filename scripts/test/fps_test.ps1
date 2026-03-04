# FPS Test Suite for YSU GPU Raytracer
# Tests various denoise configurations

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  YSU GPU Raytracer FPS Tests  " -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$testDir = "C:\YSUengine_fixed_renderc_patch_fixed2\YSUengine_fixed_renderc_patch"
Set-Location $testDir

# Configuration
$width = 1280
$height = 720
$frames = 8
$exe = "shaders\gpu_demo.exe"

if (!(Test-Path $exe)) {
    Write-Host "ERROR: $exe not found!" -ForegroundColor Red
    exit 1
}

Write-Host "GPU Demo Path: $exe" -ForegroundColor Yellow
Write-Host "Resolution: ${width}x${height}" -ForegroundColor Yellow
Write-Host "Frames: $frames" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: Existing executable may not have all new features." -ForegroundColor Magenta
Write-Host "After recompilation with Vulkan SDK, these tests will show:" -ForegroundColor Magenta
Write-Host ""

# Define test configurations
$tests = @(
    @{ Name = "Baseline (no denoise)"; Env = @{ YSU_GPU_DENOISE = "0" } },
    @{ Name = "Denoise enabled"; Env = @{ YSU_GPU_DENOISE = "1" } },
    @{ Name = "Denoise + Skip=2"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_SKIP = "2" } },
    @{ Name = "Denoise + Skip=4"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_SKIP = "4" } },
    @{ Name = "Denoise + Skip=8"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_SKIP = "8" } },
    @{ Name = "Denoise + Adaptive"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_ADAPTIVE = "1" } },
    @{ Name = "Denoise + History Reset"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_HISTORY_RESET = "1"; YSU_GPU_DENOISE_HISTORY_RESET_FRAME = "60" } },
    @{ Name = "Full Config (all features)"; Env = @{ YSU_GPU_DENOISE = "1"; YSU_GPU_DENOISE_SKIP = "4"; YSU_GPU_DENOISE_ADAPTIVE = "1"; YSU_GPU_DENOISE_HISTORY_RESET = "1"; YSU_GPU_TEMPORAL_DENOISE = "1" } }
)

# Run tests
foreach ($test in $tests) {
    Write-Host ("Test: " + $test.Name) -ForegroundColor Green
    
    # Build environment string
    $envCmd = "set YSU_GPU_W=$width & set YSU_GPU_H=$height & set YSU_GPU_FRAMES=$frames"
    foreach ($key in $test.Env.Keys) {
        $envCmd += " & set $key=$($test.Env[$key])"
    }
    
    # Run test with timing
    $startTime = [DateTime]::Now
    $output = cmd /c "$envCmd & $exe" 2>&1
    $endTime = [DateTime]::Now
    $elapsed = ($endTime - $startTime).TotalMilliseconds
    
    # Parse output for frame time
    $frameTimeMatch = $output | Select-String -Pattern "Average frame time|frame time|ms/frame" | Select-Object -First 1
    
    if ($frameTimeMatch) {
        Write-Host "  Output: $($frameTimeMatch.Line)" -ForegroundColor Cyan
    } else {
        Write-Host "  Total execution: ${elapsed}ms for $frames frames" -ForegroundColor Cyan
        $avgMs = $elapsed / $frames
        $fps = 1000 / $avgMs
        Write-Host "  Estimated: ${avgMs}ms/frame = ${fps}FPS" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  Test Suite Complete" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Expected Performance (after recompilation):" -ForegroundColor Magenta
Write-Host "  Baseline (no denoise):     ~50-80 FPS" -ForegroundColor Gray
Write-Host "  Denoise enabled:           ~50-60 FPS" -ForegroundColor Gray
Write-Host "  Denoise + Skip=2:          ~70-90 FPS" -ForegroundColor Gray
Write-Host "  Denoise + Skip=4:          ~100-120 FPS" -ForegroundColor Gray
Write-Host "  Denoise + Skip=8:          ~150-180 FPS" -ForegroundColor Gray
Write-Host "  Denoise + Adaptive:        ~95-200 FPS (ramps)" -ForegroundColor Gray
Write-Host "  Denoise + History Reset:   ~100-120 FPS" -ForegroundColor Gray
Write-Host "  Full Config:               ~95-210 FPS (ramps)" -ForegroundColor Gray
