import json
import numpy as np

with open('DataNeRF/data/nerf/fox/transforms.json', 'r') as f:
    data = json.load(f)

print(f'Number of frames: {len(data["frames"])}')

# Get camera positions from transforms
positions = []
for i, frame in enumerate(data['frames'][:5]):
    mat = np.array(frame['transform_matrix'])
    pos = mat[:3, 3]
    positions.append(pos)
    print(f'Frame {i}: pos = ({pos[0]:.2f}, {pos[1]:.2f}, {pos[2]:.2f})')

avg = np.mean(positions, axis=0)
print(f'\nAverage camera position: ({avg[0]:.2f}, {avg[1]:.2f}, {avg[2]:.2f})')

# Get trained center/scale
import struct
with open('models/nerf_hashgrid.bin', 'rb') as f:
    header = f.read(60)
vals = struct.unpack('<6I f 4I f 3f', header)
scale = vals[11]
cx, cy, cz = vals[12], vals[13], vals[14]
print(f'\nTrained center: ({cx:.2f}, {cy:.2f}, {cz:.2f})')
print(f'Trained scale: {scale:.2f}')

# The fox should be at the center, cameras orbit around it
print(f'\nDistance from avg camera to center: {np.linalg.norm(avg - np.array([cx, cy, cz])):.2f}')
