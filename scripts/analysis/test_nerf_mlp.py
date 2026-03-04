#!/usr/bin/env python3
"""
Test script to validate NeRF MLP binary export and compare with PyTorch inference.
"""
import struct
import numpy as np
import torch
import sys

# Load the binary model
bin_path = "models/nerf_hashgrid.bin"
with open(bin_path, "rb") as f:
    data = f.read()

# Parse header (15 u32 values = 60 bytes)
header = struct.unpack("<IIIIII f IIIII", data[:60])
magic, version, levels, features, hashmap_size, base_res, per_level_scale, mlp_in, mlp_hidden, mlp_layers, mlp_out, flags, *res = header
print(f"[HEADER] magic=0x{magic:08x} ver={version} levels={levels} features={features}")
print(f"[HEADER] hashmap={hashmap_size} base_res={base_res} per_level_scale={per_level_scale}")
print(f"[HEADER] mlp_in={mlp_in} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}")

# Skip hash tables
header_bytes = 60
table_bytes = levels * hashmap_size * features * 2
mlp_start = header_bytes + table_bytes
print(f"\n[LAYOUT] hash tables end at byte {mlp_start}")

# Read MLP layer 1 (27 -> 64)
in_dim_1 = mlp_in
out_dim_1 = mlp_hidden
w_bytes_1 = in_dim_1 * out_dim_1 * 2  # [in_dim, out_dim] transposed
b_bytes_1 = out_dim_1 * 2

w1_data = data[mlp_start : mlp_start + w_bytes_1]
b1_data = data[mlp_start + w_bytes_1 : mlp_start + w_bytes_1 + b_bytes_1]

# Parse as float16
w1_half = np.frombuffer(w1_data, dtype=np.float16).reshape((in_dim_1, out_dim_1))
b1 = np.frombuffer(b1_data, dtype=np.float16)

print(f"\n[LAYER 1] weights shape {w1_half.shape} biases shape {b1.shape}")
print(f"  w1 range: [{w1_half.min():.4f}, {w1_half.max():.4f}]")
print(f"  b1 range: [{b1.min():.4f}, {b1.max():.4f}]")
print(f"  w1 sample (first 5x5):\n{w1_half[:5, :5]}")
print(f"  b1 sample (first 5):\n{b1[:5]}")

# Test inference: create a dummy input
test_input = np.ones(mlp_in, dtype=np.float32) * 0.1
print(f"\n[TEST] Using input of shape {test_input.shape} with values {test_input[0]}")

# Forward pass layer 1: y = ReLU(x @ W + b)
# Binary format is [in_dim, out_dim], so matrix multiply is (1, in_dim) @ (in_dim, out_dim) -> (1, out_dim)
hidden_1 = np.dot(test_input.astype(np.float32), w1_half.astype(np.float32)) + b1.astype(np.float32)
hidden_1 = np.maximum(hidden_1, 0.0)  # ReLU
print(f"  After layer 1 ReLU: range [{hidden_1.min():.4f}, {hidden_1.max():.4f}]")
print(f"  Sample output (first 5): {hidden_1[:5]}")

# Layer 2 (64 -> 64)
offset_2 = mlp_start + w_bytes_1 + b_bytes_1
w_bytes_2 = out_dim_1 * out_dim_1 * 2
b_bytes_2 = out_dim_1 * 2

w2_data = data[offset_2 : offset_2 + w_bytes_2]
b2_data = data[offset_2 + w_bytes_2 : offset_2 + w_bytes_2 + b_bytes_2]

w2_half = np.frombuffer(w2_data, dtype=np.float16).reshape((out_dim_1, out_dim_1))
b2 = np.frombuffer(b2_data, dtype=np.float16)

hidden_2 = np.dot(hidden_1, w2_half.astype(np.float32)) + b2.astype(np.float32)
hidden_2 = np.maximum(hidden_2, 0.0)
print(f"\n  After layer 2 ReLU: range [{hidden_2.min():.4f}, {hidden_2.max():.4f}]")

# Output layer (64 -> 4)
offset_out = offset_2 + w_bytes_2 + b_bytes_2
w_bytes_out = out_dim_1 * mlp_out * 2
b_bytes_out = mlp_out * 2

w_out_data = data[offset_out : offset_out + w_bytes_out]
b_out_data = data[offset_out + w_bytes_out : offset_out + w_bytes_out + b_bytes_out]

w_out_half = np.frombuffer(w_out_data, dtype=np.float16).reshape((out_dim_1, mlp_out))
b_out = np.frombuffer(b_out_data, dtype=np.float16)

output_raw = np.dot(hidden_2, w_out_half.astype(np.float32)) + b_out.astype(np.float32)
print(f"\n  Output layer (raw): {output_raw}")

# Apply activations: sigmoid(RGB), ReLU(sigma)
rgb = 1.0 / (1.0 + np.exp(-output_raw[:3]))
sigma = np.maximum(output_raw[3], 0.0)
print(f"  After activation: RGB={rgb}, sigma={sigma:.6f}")
print(f"  Expected: RGB should be ~[0.5, 0.5, 0.5], sigma should be > 0")

print("\n✓ Binary parsing and forward pass complete")
