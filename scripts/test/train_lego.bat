@echo off
set DATA_PATH=DataNeRF/data/nerf/lego
set OUT_HASHGRID=models/nerf_hashgrid.bin
set OUT_OCC=models/nerf_occ.bin

if not exist models mkdir models

echo [NERF] Training Lego model with Trilinear sampling...
python nerf_train_and_export.py --data %DATA_PATH% --out_hashgrid %OUT_HASHGRID% --out_occ %OUT_OCC% --iters 20000 --batch_rays 4096 --n_samples 128 --occ_threshold 0.1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Training failed.
    exit /b %ERRORLEVEL%
)

echo [NERF] Training Complete.
