@echo off
REM Debug script to test NeRF integration step-by-step
REM This runs various debug render modes to diagnose issues

set YSU_NERF_HASHGRID=models/nerf_hashgrid.bin
set YSU_NERF_OCC=models/nerf_occ.bin

set YSU_W=800
set YSU_H=600
set YSU_SPP=1
set YSU_DEPTH=2
set YSU_USE_BVH=1
set YSU_NERF_STEPS=32

echo ===================================
echo   YSU NeRF Debug Modes
echo ===================================
echo.
echo Testing NeRF integration with debug render modes
echo.
echo Available debug modes:
echo   7  = BVH heatmap
echo   8  = BVH depth visualization
echo   9  = Triangle ID visualization
echo   10 = Surface normals
echo   11 = Distance field
echo   12 = Ambient occlusion
echo   13 = NeRF occupancy grid
echo   14 = NeRF hashgrid lookup
echo   15 = NeRF grid resolution
echo   16 = NeRF embedding values
echo   17 = NeRF MLP output (should show fox colors if working)
echo   18 = NeRF volume integration (full pipeline)
echo   19 = NeRF buffer validation (magic number check)
echo   20 = NeRF push constants (center/scale)
echo.
echo Recommended sequence:
echo   1. Mode 19: Verify buffer is loaded (brownish gray = OK)
echo   2. Mode 20: Verify center/scale params
echo   3. Mode 13: Verify occupancy grid
echo   4. Mode 14: Verify hashgrid lookup
echo   5. Mode 17: Verify MLP output (should show trained colors)
echo   6. Mode 18: Full NeRF integration
echo   7. Mode 2:  Hybrid mesh+NeRF blend
echo.

set /p MODE="Enter debug mode (7-20) or 2 for hybrid: "
set YSU_RENDER_MODE=%MODE%

echo.
echo Running mode %MODE%...
echo.

gpu_demo.exe

pause
