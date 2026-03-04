@echo off
setlocal enabledelayedexpansion
set YSU_GPU_WINDOW=1
set YSU_GPU_W=320
set YSU_GPU_H=180
set YSU_GPU_SPP=128
set YSU_GPU_DUMP_ONESHOT=1
echo Running window mode test...
gpu_demo.exe
echo Window mode test completed
dir window_dump.ppm
