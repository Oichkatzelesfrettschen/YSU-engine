#!/usr/bin/env python3
"""Test if NeRF model file contains valid data"""
import struct
import numpy as np
from pathlib import Path

def test_nerf_model(path="models/nerf_hashgrid.bin"):
    with open(path, "rb") as f:
        # Read header
        magic, version, levels, features, hashmap_size, base_res = struct.unpack("IIIIII", f.read(24))
        per_level_scale = struct.unpack("f", f.read(4))[0]
        mlp_in, mlp_hidden, mlp_layers, mlp_out = struct.unpack("IIII", f.read(16))
        
        print(f"Magic: 0x{magic:08X} {'✓' if magic == 0x3147484E else '✗ WRONG'}")
        print(f"Version: {version}")
        print(f"Levels: {levels}, Features: {features}")
        print(f"Hashmap size: {hashmap_size}")
        print(f"Base res: {base_res}, Per-level scale: {per_level_scale}")
        print(f"MLP: in={mlp_in}, hidden={mlp_hidden}, layers={mlp_layers}, out={mlp_out}")
        
        # Skip rest of header
        f.read(16)
        
        # Read hashgrid table
        table_size = levels * hashmap_size * features
        table_bytes = table_size * 2
        print(f"\nHashgrid table: {table_size} float16 values ({table_bytes} bytes)")
        
        table_data = np.frombuffer(f.read(table_bytes), dtype=np.float16)
        print(f"  Min: {table_data.min():.6f}")
        print(f"  Max: {table_data.max():.6f}")
        print(f"  Mean: {table_data.mean():.6f}")
        print(f"  Std: {table_data.std():.6f}")
        print(f"  Zeros: {(table_data == 0).sum()} / {len(table_data)} ({100*(table_data == 0).sum()/len(table_data):.1f}%)")
        
        if (table_data == 0).sum() > len(table_data) * 0.9:
            print("  ⚠️  WARNING: >90% zeros - model may be untrained!")
        
        # Read MLP weights
        # Layer 1: mlp_in x mlp_hidden weights + mlp_hidden biases
        w1_size = mlp_in * mlp_hidden
        b1_size = mlp_hidden
        w1_bytes = w1_size * 2
        b1_bytes = b1_size * 2
        
        print(f"\nMLP Layer 1 weights: {w1_size} float16 values")
        w1 = np.frombuffer(f.read(w1_bytes), dtype=np.float16)
        print(f"  Min: {w1.min():.6f}")
        print(f"  Max: {w1.max():.6f}")
        print(f"  Mean: {w1.mean():.6f}")
        print(f"  Std: {w1.std():.6f}")
        
        print(f"\nMLP Layer 1 biases: {b1_size} float16 values")
        b1 = np.frombuffer(f.read(b1_bytes), dtype=np.float16)
        print(f"  Min: {b1.min():.6f}")
        print(f"  Max: {b1.max():.6f}")
        print(f"  Mean: {b1.mean():.6f}")
        
        if w1.std() < 0.01:
            print("  ⚠️  WARNING: Very low std - weights may be uninitialized!")
        
        # Quick sanity check: try a forward pass with zeros
        print("\n=== Quick Forward Pass Test ===")
        print("Input: all zeros")
        hidden = b1.copy()  # With zero input, output = bias
        hidden = np.maximum(hidden, 0)  # ReLU
        print(f"Hidden layer output (first 5): {hidden[:5]}")
        
        if np.all(hidden == 0):
            print("  ✗ All zeros after ReLU - model likely broken!")
        elif np.all(np.isnan(hidden)):
            print("  ✗ NaN detected - model corrupted!")
        else:
            print("  ✓ Non-zero activations - model structure seems OK")
            
if __name__ == "__main__":
    test_nerf_model()
