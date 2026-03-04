@echo off
REM Test script - clean environment
setlocal enabledelayedexpansion
cd /d "c:\YSUengine_fixed_renderc_patch_fixed2\YSUengine_fixed_renderc_patch"

REM Clear YSU vars
for /f "delims==" %%A in ('set ^| findstr /I "^YSU"') do set "%%A="

REM Test 1: Cube (small)
echo [TEST 1] Cube 128x96
set YSU_GPU_W=128
set YSU_GPU_H=96
set YSU_GPU_DUMP_ONESHOT=1
gpu_demo.exe >nul 2>&1
python analyze_output.py output_gpu.ppm cube_debug.txt

REM Test 2: 3M 1 SPP noisy
echo [TEST 2] 3M 1 SPP Noisy
for /f "delims==" %%A in ('set ^| findstr /I "^YSU"') do set "%%A="
set YSU_GPU_W=320
set YSU_GPU_H=180
set YSU_GPU_SPP=1
set YSU_GPU_OBJ=TestSubjects/3M.obj
set YSU_NEURAL_DENOISE=0
set YSU_GPU_DUMP_ONESHOT=1
gpu_demo.exe >nul 2>&1
move /Y output_gpu.ppm output_3m_noisy.ppm >nul
python analyze_output.py output_3m_noisy.ppm noisy_debug.txt

REM Test 3: 3M 1 SPP with denoise
echo [TEST 3] 3M 1 SPP Denoised
set YSU_NEURAL_DENOISE=1
gpu_demo.exe >nul 2>&1
move /Y output_gpu.ppm output_3m_denoised.ppm >nul
python analyze_output.py output_3m_denoised.ppm denoised_debug.txt

REM Test 4: 3M 8 SPP clean
echo [TEST 4] 3M 8 SPP Clean
set YSU_NEURAL_DENOISE=0
set YSU_GPU_SPP=8
gpu_demo.exe >nul 2>&1
move /Y output_gpu.ppm output_3m_8spp.ppm >nul
python analyze_output.py output_3m_8spp.ppm clean_debug.txt

echo.
echo Results:
type cube_debug.txt
type noisy_debug.txt
type denoised_debug.txt
type clean_debug.txt
