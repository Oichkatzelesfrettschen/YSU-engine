"""
Automated benchmark script for Depth-Conditioned NeRF
Runs multiple scenes, collects FPS, and generates comparison table.

Usage:
    python benchmark_nerf_modes.py [--scenes lego,drums,ship] [--duration 10]
"""

import subprocess
import os
import re
import sys
import time
import argparse
from pathlib import Path

def run_renderer(mode, model, occ, duration=10):
    """Run renderer and capture FPS from output."""
    env = os.environ.copy()
    env['YSU_GPU_WINDOW'] = '1'
    env['YSU_GPU_W'] = '2048'
    env['YSU_GPU_H'] = '1024'
    env['YSU_GPU_RENDER_SCALE'] = '0.5'
    env['YSU_RENDER_MODE'] = str(mode)
    env['YSU_NERF_HASHGRID'] = model
    env['YSU_NERF_OCC'] = occ
    
    print(f"  Running mode {mode}... (close window after {duration}s)")
    
    try:
        result = subprocess.run(
            ['./gpu_vulkan_demo.exe'],
            env=env,
            capture_output=True,
            text=True,
            timeout=duration + 30
        )
        output = result.stdout + result.stderr
        
        # Parse FPS from output
        fps_match = re.search(r'last FPS: ([\d.]+)', output)
        if fps_match:
            return float(fps_match.group(1))
        
        # Parse hit rate
        hit_match = re.search(r'(\d+\.\d+)% - sparse sampling', output)
        hit_rate = float(hit_match.group(1)) if hit_match else 0.0
        
        return None, hit_rate
    except subprocess.TimeoutExpired:
        return None
    except Exception as e:
        print(f"  Error: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description='Benchmark NeRF rendering modes')
    parser.add_argument('--scenes', default='lego_5k', help='Comma-separated scene names')
    parser.add_argument('--duration', type=int, default=10, help='Seconds per test')
    args = parser.parse_args()
    
    scenes = args.scenes.split(',')
    results = []
    
    print("=" * 60)
    print(" Depth-Conditioned NeRF Benchmark")
    print("=" * 60)
    
    for scene in scenes:
        model = f"models/{scene}.bin"
        occ = f"models/{scene}_occ.bin"
        
        if not Path(model).exists():
            print(f"Skipping {scene}: {model} not found")
            continue
        
        print(f"\nScene: {scene}")
        print("-" * 40)
        
        # Mode 3 baseline
        fps_baseline = run_renderer(3, model, occ, args.duration)
        
        # Mode 26 depth-conditioned
        fps_depth = run_renderer(26, model, occ, args.duration)
        
        if fps_baseline and fps_depth:
            speedup = (fps_depth / fps_baseline - 1) * 100
            results.append({
                'scene': scene,
                'mode3_fps': fps_baseline,
                'mode26_fps': fps_depth,
                'speedup': speedup
            })
            print(f"  Mode 3:  {fps_baseline:.1f} FPS")
            print(f"  Mode 26: {fps_depth:.1f} FPS")
            print(f"  Speedup: {speedup:+.1f}%")
    
    # Summary table
    print("\n" + "=" * 60)
    print(" Results Summary")
    print("=" * 60)
    print(f"{'Scene':<15} {'Mode 3 FPS':<12} {'Mode 26 FPS':<12} {'Speedup':<10}")
    print("-" * 60)
    for r in results:
        print(f"{r['scene']:<15} {r['mode3_fps']:<12.1f} {r['mode26_fps']:<12.1f} {r['speedup']:+.1f}%")
    
    # Save CSV
    csv_path = f"benchmark_results_{int(time.time())}.csv"
    with open(csv_path, 'w') as f:
        f.write("scene,mode3_fps,mode26_fps,speedup_percent\n")
        for r in results:
            f.write(f"{r['scene']},{r['mode3_fps']:.1f},{r['mode26_fps']:.1f},{r['speedup']:.1f}\n")
    print(f"\nResults saved to {csv_path}")

if __name__ == '__main__':
    main()
