#!/usr/bin/env python3
import struct, os
path = "models/nerf_hashgrid.bin"
with open(path, "rb") as f:
    blob = f.read()
fmt = "<IIIIII f IIIII 3I"
hsz = struct.calcsize(fmt)
vals = struct.unpack(fmt, blob[:hsz])
magic, ver, levels, features, hashmap_size, base_res, pls, mlp_in, mlp_hidden, mlp_layers, mlp_out, scale_u, cx_u, cy_u, cz_u = vals
print(f"magic=0x{magic:08x} ver={ver} levels={levels} features={features} mlp_in={mlp_in} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}")
header_bytes = hsz
entry_words = (features + 1)//2
expected_tables_bytes = levels * hashmap_size * features * 2
alt_tables_bytes_words = levels * hashmap_size * entry_words * 4
print(f"expected_tables_bytes={expected_tables_bytes} alt_words_bytes={alt_tables_bytes_words}")
print(f"file_size={len(blob)}")
# Try reading next two linear layers assuming tables_bytes by features
w1_bytes = mlp_in * mlp_hidden * 2
b1_bytes = mlp_hidden * 2
w2_bytes = mlp_hidden * mlp_hidden * 2
b2_bytes = mlp_hidden * 2
wout_bytes = mlp_hidden * mlp_out * 2
bout_bytes = mlp_out * 2
sum_weights = w1_bytes+b1_bytes+w2_bytes+b2_bytes+wout_bytes+bout_bytes
print(f"sum_weights_bytes={sum_weights}")
start = header_bytes + expected_tables_bytes
end = start + sum_weights
print(f"start={start} end={end} tail={len(blob)-end}")
if end>len(blob):
    print("WARNING: computed end beyond file; header features likely wrong")
# Try with features=4
features4 = 4
expected_tables_bytes4 = levels * hashmap_size * features4 * 2
start4 = header_bytes + expected_tables_bytes4
end4 = start4 + sum_weights
print(f"try features=4 -> start={start4} end={end4} tail={len(blob)-end4}")
