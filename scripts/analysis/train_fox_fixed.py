#!/usr/bin/env python3
"""
Quick test training script with fixed hyperparameters for fox dataset
"""
import subprocess
import sys

# Use the existing training script but with much better settings
cmd = [
    sys.executable,
    "nerf_train_and_export.py",
    "--data", "DataNeRF/data/nerf/fox",
    "--iters", "3000",
    "--lr", "0.001",  # Lower learning rate for stability
    "--batch_rays", "512",  # Smaller batches
]

print("Training NeRF with optimized settings...")
print(f"Command: {' '.join(cmd)}")
subprocess.run(cmd)

print("\n" + "="*60)
print("Training complete! Now render with:")
print('  $env:YSU_RENDER_MODE="2"; $env:YSU_GPU_SPP="64"; $env:YSU_GPU_TEMPORAL="0"; .\\gpu_demo.exe')
print("="*60)
