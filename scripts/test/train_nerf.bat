@echo off
REM Train a NeRF model with proper settings for depth-conditioned rendering
REM Usage: train_nerf.bat [scene] [iterations]
REM Example: train_nerf.bat lego 35000

setlocal enabledelayedexpansion

set SCENE=%1
set ITERS=%2

if "%SCENE%"=="" set SCENE=lego
if "%ITERS%"=="" set ITERS=35000

set DATA_PATH=nerf-synthetic/nerf_synthetic/%SCENE%
set OUT_MODEL=models/%SCENE%.bin
set OUT_OCC=models/%SCENE%_occ.bin

echo ============================================
echo  NeRF Training for Depth-Conditioned Rendering
echo ============================================
echo Scene: %SCENE%
echo Iterations: %ITERS%
echo Output: %OUT_MODEL%, %OUT_OCC%
echo.

REM Check if data exists
if not exist "%DATA_PATH%" (
    echo [ERROR] Dataset not found: %DATA_PATH%
    echo Please download from: https://drive.google.com/drive/folders/128yBriW1IG_3NJ5Rp7APSTZsJqdJdfc1
    exit /b 1
)

REM Activate venv if exists
if exist ".venv\Scripts\activate.bat" (
    call .venv\Scripts\activate.bat
)

REM Create models directory
if not exist "models" mkdir models

echo [TRAIN] Starting training...
python nerf_instant_ngp_fixed.py ^
    --data %DATA_PATH% ^
    --iters %ITERS% ^
    --hidden 64 ^
    --levels 16 ^
    --out_hashgrid %OUT_MODEL% ^
    --out_occ %OUT_OCC%

if errorlevel 1 (
    echo [ERROR] Training failed
    exit /b 1
)

echo.
echo ============================================
echo  Training Complete!
echo ============================================
echo Model saved to: %OUT_MODEL%
echo Occupancy saved to: %OUT_OCC%
echo.
echo To render:
echo   set YSU_RENDER_MODE=26
echo   set YSU_NERF_HASHGRID=%OUT_MODEL%
echo   set YSU_NERF_OCC=%OUT_OCC%
echo   gpu_vulkan_demo.exe
