@echo off
REM Final clean test
setlocal enabledelayedexpansion

cd /d "c:\YSUengine_fixed_renderc_patch_fixed2\YSUengine_fixed_renderc_patch"

REM Clear all YSU env vars first
for /f "delims==" %%A in ('set') do (
    if "%%A:~0,3%%"=="YSU" set "%%A="
)

REM Test 3M with current shader (has ray dir visualization)
echo [1] Rendering 3M 1 SPP noisy...
set YSU_GPU_W=320
set YSU_GPU_H=180
set YSU_GPU_SPP=1
set YSU_GPU_OBJ=TestSubjects/3M.obj
set YSU_NEURAL_DENOISE=0
set YSU_GPU_DUMP_ONESHOT=1

timeout /t 2 >nul
gpu_demo.exe >con 2>&1
if exist output_gpu.ppm (
    move /Y output_gpu.ppm output_3m_noisy_final.ppm >nul
    echo  Written: output_3m_noisy_final.ppm
) else (
    echo  FAILED: output_gpu.ppm not created
)

echo [2] Rendering 3M 1 SPP with denoise...
set YSU_NEURAL_DENOISE=1
timeout /t 2 >nul
gpu_demo.exe >con 2>&1
if exist output_gpu.ppm (
    move /Y output_gpu.ppm output_3m_denoised_final.ppm >nul
    echo  Written: output_3m_denoised_final.ppm
) else (
    echo  FAILED
)

echo [3] Rendering 3M 8 SPP clean...
set YSU_NEURAL_DENOISE=0
set YSU_GPU_SPP=8
timeout /t 2 >nul
gpu_demo.exe >con 2>&1
if exist output_gpu.ppm (
    move /Y output_gpu.ppm output_3m_clean_final.ppm >nul
    echo  Written: output_3m_clean_final.ppm
) else (
    echo  FAILED
)

echo.
echo Analysis:
python final_comparison.py
