@echo off
REM Automated test script: generates 3 comparison images then analyzes with Python
setlocal enabledelayedexpansion

echo ============================================================
echo DENOISER EFFECTIVENESS TEST
echo ============================================================
echo.

REM Check if gpu_demo.exe exists
if not exist gpu_demo.exe (
    echo ERROR: gpu_demo.exe not found
    echo Please build first: gcc -std=c11 -O2 -pthread -o gpu_demo.exe ...
    exit /b 1
)

REM Check if Python is available
where python >nul 2>&1
if errorlevel 1 (
    echo WARNING: Python not found. Will skip analysis.
    echo You can run manually: python test_denoise_effectiveness.py
    set SKIP_PYTHON=1
) else (
    set SKIP_PYTHON=0
)

echo.
echo Step 1: Generating test images...
echo.

REM Test 1: 4 SPP WITHOUT denoiser
echo [1/3] Rendering 4 SPP WITHOUT denoiser...
set YSU_GPU_WINDOW=1
set YSU_GPU_W=320
set YSU_GPU_H=180
set YSU_GPU_SPP=4
set YSU_GPU_DUMP_ONESHOT=1
set YSU_NEURAL_DENOISE=0

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_4spp_noisy.ppm
    echo      ✓ Generated: window_dump_4spp_noisy.ppm
) else (
    echo      ✗ FAILED to generate noisy image
    exit /b 1
)

REM Test 2: 4 SPP WITH denoiser
echo [2/3] Rendering 4 SPP WITH denoiser...
set YSU_NEURAL_DENOISE=1

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_4spp_denoised.ppm
    echo      ✓ Generated: window_dump_4spp_denoised.ppm
) else (
    echo      ✗ FAILED to generate denoised image
    exit /b 1
)

REM Test 3: 32 SPP clean reference
echo [3/3] Rendering 32 SPP clean reference...
set YSU_GPU_SPP=32
set YSU_NEURAL_DENOISE=0

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_32spp_clean.ppm
    echo      ✓ Generated: window_dump_32spp_clean.ppm
) else (
    echo      ✗ FAILED to generate clean reference
    exit /b 1
)

echo.
echo ============================================================
echo Step 2: Analyzing denoiser effectiveness...
echo ============================================================
echo.

if %SKIP_PYTHON%==0 (
    python test_denoise_effectiveness.py
    if errorlevel 1 (
        echo.
        echo Analysis complete. Check results above.
    )
) else (
    echo Python not available. Images generated:
    echo   - window_dump_4spp_noisy.ppm
    echo   - window_dump_4spp_denoised.ppm
    echo   - window_dump_32spp_clean.ppm
    echo.
    echo Open these in an image viewer to compare visually.
)

echo.
echo ============================================================
echo Test complete!
echo ============================================================
echo.
echo Next steps:
echo   1. Open the three PPM files in an image viewer
echo   2. Compare the visual quality
echo   3. noisy should be very grainy
echo   4. denoised should be smooth
echo   5. clean should be reference quality
echo.
