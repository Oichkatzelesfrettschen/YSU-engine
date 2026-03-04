@echo off
REM Better denoiser test: uses 1 SPP (very noisy) vs 16 SPP (reference) to show denoising effect
setlocal enabledelayedexpansion

echo ============================================================
echo DENOISER EFFECTIVENESS TEST (High Noise Configuration)
echo ============================================================
echo.

REM Check if gpu_demo.exe exists
if not exist gpu_demo.exe (
    echo ERROR: gpu_demo.exe not found
    exit /b 1
)

echo.
echo Step 1: Generating test images (1 SPP for high noise)...
echo.

REM Test 1: 1 SPP WITHOUT denoiser (very noisy)
echo [1/3] Rendering 1 SPP WITHOUT denoiser (very noisy)...
set YSU_GPU_WINDOW=1
set YSU_GPU_W=320
set YSU_GPU_H=180
set YSU_GPU_SPP=1
set YSU_GPU_DUMP_ONESHOT=1
set YSU_NEURAL_DENOISE=0
set YSU_GPU_SEED=42

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_1spp_noisy.ppm
    echo      ✓ Generated: window_dump_1spp_noisy.ppm (VERY NOISY)
) else (
    echo      ✗ FAILED
    exit /b 1
)

REM Test 2: 1 SPP WITH denoiser (should be much cleaner)
echo [2/3] Rendering 1 SPP WITH denoiser (cleaned up)...
set YSU_NEURAL_DENOISE=1

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_1spp_denoised.ppm
    echo      ✓ Generated: window_dump_1spp_denoised.ppm (DENOISED)
) else (
    echo      ✗ FAILED
    exit /b 1
)

REM Test 3: 16 SPP clean reference (multiple samples)
echo [3/3] Rendering 16 SPP reference (clean)...
set YSU_GPU_SPP=16
set YSU_NEURAL_DENOISE=0

gpu_demo.exe >nul 2>&1
if exist window_dump.ppm (
    rename window_dump.ppm window_dump_16spp_clean.ppm
    echo      ✓ Generated: window_dump_16spp_clean.ppm (REFERENCE)
) else (
    echo      ✗ FAILED
    exit /b 1
)

echo.
echo ============================================================
echo Step 2: Analyzing with Python...
echo ============================================================
echo.

REM Create temporary Python script for this test
(
echo import sys, struct, math
echo from pathlib import Path
echo.
echo def load_ppm(f):
echo     with open(f, 'rb') as fp:
echo         magic = fp.readline().decode().strip()
echo         while True:
echo             line = fp.readline().decode().strip()
echo             if line and not line.startswith('#'): break
echo         w, h = map(int, line.split())
echo         fp.readline()  # maxval
echo         data = fp.read(w * h * 3)
echo         pixels = [[data[i]/255.0, data[i+1]/255.0, data[i+2]/255.0] for i in range(0, len(data), 3)]
echo         return w, h, pixels
echo.
echo def var(p): lum = [0.2126*r + 0.7152*g + 0.0722*b for r,g,b in p]; m = sum(lum)/len(lum); return sum((x-m)**2 for x in lum)/len(lum)
echo def psnr(p1, p2):
echo     mse = sum(((p1[i][j]-p2[i][j])**2 for i in range(len(p1)) for j in range(3))) / (len(p1)*3)
echo     return 20*math.log10(1)-10*math.log10(mse) if mse > 1e-10 else 100
echo.
echo w,h,noisy = load_ppm('window_dump_1spp_noisy.ppm')
echo _,_,denoised = load_ppm('window_dump_1spp_denoised.ppm')
echo _,_,clean = load_ppm('window_dump_16spp_clean.ppm')
echo.
echo v_noisy = var(noisy)
echo v_denoised = var(denoised)
echo v_clean = var(clean)
echo.
echo print('=' * 60)
echo print('NOISE LEVEL (Variance - lower is better)')
echo print('=' * 60)
echo print(f'  1 SPP noisy:       {v_noisy:8.2f}')
echo print(f'  1 SPP denoised:    {v_denoised:8.2f}  ', end='')
echo if v_denoised ^< v_noisy:
echo     reduction = (v_noisy - v_denoised) / v_noisy * 100
echo     print(f'REDUCTION: {reduction:.1f}%%')
echo else:
echo     print('(no improvement)')
echo print(f'  16 SPP clean:      {v_clean:8.2f}')
echo print()
echo.
echo print('QUALITY vs 16 SPP (PSNR - higher is better)')
echo print('=' * 60)
echo p_noisy = psnr(noisy, clean)
echo p_denoised = psnr(denoised, clean)
echo print(f'  1 SPP noisy:       {p_noisy:7.2f} dB')
echo print(f'  1 SPP denoised:    {p_denoised:7.2f} dB  ', end='')
echo if p_denoised ^> p_noisy:
echo     print(f'IMPROVED: +{p_denoised-p_noisy:.2f} dB')
echo else:
echo     print('(no improvement)')
echo print()
echo.
echo if v_denoised ^< v_noisy * 0.5 and p_denoised ^> p_noisy + 2:
echo     print('RESULT: ✅ DENOISER WORKING EFFECTIVELY')
echo elif v_denoised ^< v_noisy:
echo     print('RESULT: ✓ Denoiser is reducing noise')
echo else:
echo     print('RESULT: ⚠️  Denoiser showed minimal effect')
echo print('=' * 60)
) > analyze_denoise_temp.py

python analyze_denoise_temp.py
del analyze_denoise_temp.py

echo.
echo ============================================================
echo Test complete!
echo ============================================================
echo.
echo Files generated:
echo   - window_dump_1spp_noisy.ppm (reference: very noisy)
echo   - window_dump_1spp_denoised.ppm (test: denoiser applied)
echo   - window_dump_16spp_clean.ppm (target: clean reference)
echo.
echo Comparison tips:
echo   - Noisy should look very grainy/speckled
echo   - Denoised should be much smoother
echo   - Clean should be the smoothest
echo.
