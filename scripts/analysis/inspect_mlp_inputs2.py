#!/usr/bin/env python3
import struct, numpy as np
path = "models/nerf_hashgrid.bin"
fmt = "<IIIIII f IIIII 3I"
with open(path, "rb") as f:
    blob = f.read()
header_size = struct.calcsize(fmt)
magic, ver, levels, features, hashmap_size, base_res, pls, mlp_in, mlp_hidden, mlp_layers, mlp_out, scale_u, cx_u, cy_u, cz_u = struct.unpack(fmt, blob[:header_size])
start = header_size + levels*hashmap_size*features*2
w1_bytes = mlp_in * mlp_hidden * 2
w1 = np.frombuffer(blob[start:start+w1_bytes], dtype=np.float16).astype(np.float32).reshape(mlp_in, mlp_hidden)
norms = np.linalg.norm(w1, axis=1)
print(f"mlp_in={mlp_in}")
for i in list(range(24, 31)) + list(range(46, 51)):
    print(f"dim {i}: norm={norms[i]:.4f}")
