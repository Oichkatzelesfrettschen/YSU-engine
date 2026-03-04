@echo off
REM Quick run script for Mode 26 (depth-conditioned NeRF)

set YSU_GPU_WINDOW=1
set YSU_GPU_W=1920
set YSU_GPU_H=1080
set YSU_GPU_RENDER_SCALE=0.5
set YSU_RENDER_MODE=26
set YSU_NERF_HASHGRID=models/lego_5k.bin
set YSU_NERF_OCC=models/lego_5k_occ.bin

echo [RUN] Starting Depth-Conditioned NeRF Renderer
echo [RUN] Mode: 26 (adaptive 8-32 steps)
echo [RUN] Model: %YSU_NERF_HASHGRID%
echo [RUN] Controls: WASD=move, Mouse=look, ESC=quit, M=mode
echo.

.\gpu_vulkan_demo.exe
