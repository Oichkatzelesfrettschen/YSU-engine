import struct
import numpy as np

# Load model exactly as shader would
with open('models/nerf_hashgrid.bin', 'rb') as f:
    raw = f.read()

# Parse as uint32 array (like GLSL buffer)
data = np.frombuffer(raw, dtype=np.uint32)

print('Header as shader sees it:')
print(f'  data[0] = 0x{data[0]:08X} (magic)')
print(f'  data[2] = {data[2]} (levels)')
print(f'  data[3] = {data[3]} (features)')
print(f'  data[4] = {data[4]} (hashmap_size)')
print(f'  data[5] = {data[5]} (base_res)')

pls = struct.unpack('<f', struct.pack('<I', data[6]))[0]
print(f'  data[6] = {pls:.4f} (per_level_scale)')
print(f'  data[7] = {data[7]} (mlp_in)')
print(f'  data[8] = {data[8]} (mlp_hidden)')
print(f'  data[9] = {data[9]} (mlp_layers)')
print(f'  data[10] = {data[10]} (mlp_out)')

scale = struct.unpack('<f', struct.pack('<I', data[11]))[0]
cx = struct.unpack('<f', struct.pack('<I', data[12]))[0]
cy = struct.unpack('<f', struct.pack('<I', data[13]))[0]
cz = struct.unpack('<f', struct.pack('<I', data[14]))[0]
print(f'  data[11] = {scale:.4f} (scale)')
print(f'  data[12-14] = ({cx:.2f}, {cy:.2f}, {cz:.2f}) (center)')

def nerf_half(byte_offset):
    return np.frombuffer(raw[byte_offset:byte_offset+2], dtype=np.float16)[0]

header_bytes = 15 * 4  # 60
levels = data[2]
features = data[3]
hashmap_size = data[4]
base_res = data[5]

# Simulate shader for center of screen
# Camera at (3.17, -5.48, -0.98), looking toward center
cam_pos = np.array([3.17, -5.48, -0.98])
center = np.array([cx, cy, cz])

# Ray toward center (approximate)
to_center = center - cam_pos
rd = to_center / np.linalg.norm(to_center)

# Mid-ray point
t = 5.0  # nerf_bounds * 0.5
p = cam_pos + rd * t
print(f'\nTest point: p = {p}')

# nerf_local
local_p = (p - center) / scale
pn = np.clip(local_p * 0.5 + 0.5, 0, 1)
print(f'local_p = {local_p}')
print(f'pn = {pn}')

# Compute embedding exactly as shader
embed = []
for l in range(levels):
    res_f = base_res * (pls ** l)
    res = int(res_f)  # floor
    grid = pn * res
    gi = np.floor(grid).astype(int)
    hx, hy, hz = max(gi[0], 0), max(gi[1], 0), max(gi[2], 0)
    h = ((hx * 73856093) ^ (hy * 19349663) ^ (hz * 83492791)) % hashmap_size
    
    entry = (l * hashmap_size + h) * features
    for f in range(features):
        byte_off = header_bytes + (entry + f) * 2
        val = float(nerf_half(byte_off))
        embed.append(val)
    
    if l < 3:
        print(f'  L{l}: res={res} gi={gi} h={h} vals=[{embed[-2]:.4f}, {embed[-1]:.4f}]')

embed = np.array(embed, dtype=np.float32)
print(f'\nEmbedding: len={len(embed)}, first 6: {embed[:6]}')

# Add view direction
view = rd.astype(np.float32)
mlp_in = np.concatenate([embed, view])
print(f'MLP input: len={len(mlp_in)}, last 3: {mlp_in[-3:]}')

# Now evaluate MLP exactly as shader does
table_bytes = levels * hashmap_size * features * 2
offset = header_bytes + table_bytes

mlp_hidden = data[8]
mlp_layers = data[9]
mlp_out = data[10]

print(f'\nMLP: in={len(mlp_in)} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}')
print(f'MLP weights start at byte {offset}')

# Layer 1: in_dim=27, out_dim=64
in_dim = len(mlp_in)
out_dim = mlp_hidden
cur = np.zeros(out_dim, dtype=np.float32)

for o in range(out_dim):
    sum_val = 0.0
    for j in range(in_dim):
        w_off = offset + (j * out_dim + o) * 2
        w = float(nerf_half(w_off))
        sum_val += w * mlp_in[j]
    b_off = offset + in_dim * out_dim * 2 + o * 2
    b = float(nerf_half(b_off))
    sum_val += b
    cur[o] = max(sum_val, 0.0)  # ReLU

offset += (out_dim * in_dim + out_dim) * 2
print(f'After layer 1: mean={cur.mean():.4f} max={cur.max():.4f}')

# Layer 2: in_dim=64, out_dim=64
in_dim = mlp_hidden
nxt = np.zeros(out_dim, dtype=np.float32)
for o in range(out_dim):
    sum_val = 0.0
    for j in range(in_dim):
        w_off = offset + (j * out_dim + o) * 2
        w = float(nerf_half(w_off))
        sum_val += w * cur[j]
    b_off = offset + in_dim * out_dim * 2 + o * 2
    b = float(nerf_half(b_off))
    sum_val += b
    nxt[o] = max(sum_val, 0.0)
cur = nxt

offset += (out_dim * in_dim + out_dim) * 2
print(f'After layer 2: mean={cur.mean():.4f} max={cur.max():.4f}')

# Output layer: in_dim=64, out_dim=4
in_dim = mlp_hidden
out_dim = mlp_out
outv = np.zeros(4, dtype=np.float32)
for o in range(min(out_dim, 4)):
    sum_val = 0.0
    for j in range(in_dim):
        w_off = offset + (j * out_dim + o) * 2
        w = float(nerf_half(w_off))
        sum_val += w * cur[j]
    b_off = offset + in_dim * out_dim * 2 + o * 2
    b = float(nerf_half(b_off))
    sum_val += b
    outv[o] = sum_val

print(f'Raw output: {outv}')

rgb = 1.0 / (1.0 + np.exp(-outv[:3]))
sigma = max(outv[3], 0)
print(f'RGB (sigmoid): {rgb}')
print(f'Sigma (relu): {sigma}')
