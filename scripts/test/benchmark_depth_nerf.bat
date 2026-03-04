@echo off
REM Run benchmark comparing Mode 3 (baseline) vs Mode 26 (depth-conditioned)
REM Outputs FPS and performance metrics

setlocal enabledelayedexpansion

set MODEL=%1
set OCC=%2

if "%MODEL%"=="" set MODEL=models/lego_5k.bin
if "%OCC%"=="" set OCC=models/lego_5k_occ.bin

echo ============================================
echo  Depth-Conditioned NeRF Benchmark
echo ============================================
echo Model: %MODEL%
echo Occupancy: %OCC%
echo.

REM Common settings
set YSU_GPU_WINDOW=1
set YSU_GPU_W=2048
set YSU_GPU_H=1024
set YSU_GPU_RENDER_SCALE=0.5
set YSU_NERF_HASHGRID=%MODEL%
set YSU_NERF_OCC=%OCC%

echo [TEST 1] Mode 3 - Baseline NeRF (32 uniform steps)
echo Press ESC after ~10 seconds to record FPS
set YSU_RENDER_MODE=3
.\gpu_vulkan_demo.exe

echo.
echo [TEST 2] Mode 26 - Depth-Conditioned NeRF (8-32 adaptive steps)
echo Press ESC after ~10 seconds to record FPS
set YSU_RENDER_MODE=26
.\gpu_vulkan_demo.exe

echo.
echo ============================================
echo  Benchmark Complete
echo ============================================
echo Compare the "last FPS" values from each run.
echo Speedup = (Mode26 FPS / Mode3 FPS - 1) * 100%%
