@echo off
set YSU_GPU_W=800
set YSU_GPU_H=800
set YSU_GPU_SPP=4
set YSU_GPU_WINDOW=1
set YSU_GPU_TEMPORAL=1
set YSU_GPU_TONEMAP=1
set YSU_DUMP_RGB=1
set YSU_RENDER_MODE=3
set YSU_NERF_HASHGRID=models/nerf_hashgrid.bin
set YSU_NERF_OCC=models/nerf_occ.bin
set YSU_NERF_STEPS=128
set YSU_NERF_BOUNDS=10.0
set YSU_NERF_CENTER_X=0.0
set YSU_NERF_CENTER_Y=0.0
set YSU_NERF_CENTER_Z=0.0
set YSU_NERF_SCALE=1.5
set YSU_NERF_DENSITY=1.0
set YSU_NERF_STRENGTH=1.0
set YSU_NERF_SKIP_OCC=1
set YSU_GPU_RENDER_SCALE=1.0

echo [LEGO] Starting GPU NeRF Engine...
echo [LEGO] Mode: %YSU_RENDER_MODE% (Full Volumetric)
echo [LEGO] Bounds: %YSU_NERF_BOUNDS%
echo [LEGO] Steps: %YSU_NERF_STEPS%

.\gpu_vulkan_demo.exe
