@echo off
REM Quick-start script for GPU NeRF demo
REM Sets up environment variables and runs the GPU demo

REM === NeRF Model Files ===
set YSU_NERF_HASHGRID=models/nerf_hashgrid.bin
set YSU_NERF_OCC=models/nerf_occ.bin

REM === Render Mode ===
REM 0 = mesh only
REM 1 = probe placeholder
REM 2 = hybrid (mesh + NeRF blend)
REM 3 = NeRF only (full volumetric)
REM 7-20 = debug modes (see shader tri.comp for details)
set YSU_RENDER_MODE=2

REM === NeRF Parameters ===
set YSU_NERF_BLEND=0.35
set YSU_NERF_STRENGTH=1.0
set YSU_NERF_DENSITY=1.0
set YSU_NERF_BOUNDS=8.0
set YSU_NERF_STEPS=64
set YSU_NERF_SKIP_OCC=0

REM === Optional: Override center/scale (usually auto-detected from .bin file) ===
REM set YSU_NERF_CENTER_X=0.0
REM set YSU_NERF_CENTER_Y=0.0
REM set YSU_NERF_CENTER_Z=0.0
REM set YSU_NERF_SCALE=1.0

REM === Window/Rendering Settings ===
set YSU_W=1280
set YSU_H=720
set YSU_SPP=4
set YSU_DEPTH=4

REM === BVH Settings ===
set YSU_USE_BVH=1
set YSU_GPU_BVH_CACHE=cache/bunny.bvhbin

REM === Optional: Enable GPU denoiser ===
REM set YSU_GPU_DENOISE=1
REM set YSU_GPU_DENOISE_RADIUS=3

echo ===================================
echo   YSU NeRF GPU Demo
echo ===================================
echo.
echo Render Mode: %YSU_RENDER_MODE%
echo NeRF HashGrid: %YSU_NERF_HASHGRID%
echo NeRF Occupancy: %YSU_NERF_OCC%
echo Resolution: %YSU_W%x%YSU_H%
echo NeRF Steps: %YSU_NERF_STEPS%
echo NeRF Blend: %YSU_NERF_BLEND%
echo.
echo Starting demo...
echo.

gpu_demo.exe
