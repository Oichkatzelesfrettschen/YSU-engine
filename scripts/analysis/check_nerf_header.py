import struct
with open('models/nerf_hashgrid.bin', 'rb') as f:
    h = struct.unpack('<15I', f.read(60))
    scale = struct.unpack('<f', struct.pack('<I', h[11]))[0]
    cx = struct.unpack('<f', struct.pack('<I', h[12]))[0]
    cy = struct.unpack('<f', struct.pack('<I', h[13]))[0]
    cz = struct.unpack('<f', struct.pack('<I', h[14]))[0]
    print(f"Scale: {scale}")
    print(f"Center: ({cx}, {cy}, {cz})")
