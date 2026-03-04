import struct

fmt = "<IIIIII f IIIII 3I"
print(f"Format: {fmt}")
print(f"Size: {struct.calcsize(fmt)} bytes")

# Count fields:
# IIIIII = 6 u32
# f = float
# IIIII = 5 u32
# 3I = 3 u32
# Total = 14 u32 + 1 float = 14*4 + 4 = 60 bytes (with padding)

with open("models/nerf_hashgrid.bin", "rb") as f:
    data = f.read(80)
    print(f"\nActual file size start: {len(data)} bytes read")
    print(f"First 64 bytes (hex):\n{data[:64].hex()}")
    
    # Try to unpack
    try:
        vals = struct.unpack(fmt, data[:struct.calcsize(fmt)])
        print(f"\nUnpacked header ({len(vals)} values):")
        for i, v in enumerate(vals):
            print(f"  [{i}]: {v}")
    except Exception as e:
        print(f"Error: {e}")
