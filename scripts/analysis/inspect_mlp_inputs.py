#!/usr/bin/env python3
import struct, numpy as np
path = "models/nerf_hashgrid.bin"
fmt = "<IIIIII f IIIII 3I"
with open(path, "rb") as f:
    blob = f.read()
header_size = struct.calcsize(fmt)
magic, ver, levels, features, hashmap_size, base_res, pls, mlp_in, mlp_hidden, mlp_layers, mlp_out, scale_u, cx_u, cy_u, cz_u = struct.unpack(fmt, blob[:header_size])
print(f"levels={levels} features={features} mlp_in={mlp_in} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}")
start = header_size + levels*hashmap_size*features*2
w1_bytes = mlp_in * mlp_hidden * 2
b1_bytes = mlp_hidden * 2
w1 = np.frombuffer(blob[start:start+w1_bytes], dtype=np.float16).astype(np.float32).reshape(mlp_in, mlp_hidden)
# Compute per-input L2 norm across outgoing weights
norms = np.linalg.norm(w1, axis=1)
print("Top input dims by norm:")
idx = np.argsort(-norms)
for k in range(min(10, len(idx))):
    i = idx[k]
    print(f"  dim {i}: norm={norms[i]:.4f}")
print("\nFirst 30 dims norms:")
for i in range(min(mlp_in,30)):
    print(f"  {i}: {norms[i]:.4f}")
