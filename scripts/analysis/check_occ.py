import struct
import numpy as np
with open('models/nerf_occ.bin', 'rb') as f:
    hdr = struct.unpack('<IIff', f.read(16))
    print(f"Occ Header: dim={hdr[1]}, scale={hdr[2]}, threshold={hdr[3]}")
    data = np.frombuffer(f.read(), dtype=np.uint8)
    print(f"Occ data: {len(data)} bytes, non-zero: {np.sum(data > 0)} ({100*np.sum(data > 0)/len(data):.2f}%)")
