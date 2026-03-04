#!/usr/bin/env python3
"""
CPU reference render using the same model format as GPU shader.
This helps verify the GPU shader is correct.
"""
import numpy as np
import struct
from PIL import Image

def load_nerf_model(path):
    """Load NeRF model from binary file."""
    with open(path, 'rb') as f:
        data = f.read()
    
    # Parse header (15 uint32 = 60 bytes)
    header = struct.unpack('<15I', data[:60])
    magic, version = header[0], header[1]
    levels, features, hashmap_size, base_res = header[2:6]
    per_level_scale = struct.unpack('<f', struct.pack('<I', header[6]))[0]
    mlp_in, mlp_hidden, mlp_layers, mlp_out = header[7:11]
    scale = struct.unpack('<f', struct.pack('<I', header[11]))[0]
    cx = struct.unpack('<f', struct.pack('<I', header[12]))[0]
    cy = struct.unpack('<f', struct.pack('<I', header[13]))[0]
    cz = struct.unpack('<f', struct.pack('<I', header[14]))[0]
    
    print(f"Model: L={levels} F={features} H={hashmap_size} base={base_res}")
    print(f"MLP: in={mlp_in} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}")
    print(f"Scene: center=({cx},{cy},{cz}) scale={scale}")
    
    offset = 60
    
    # Hash tables: levels * hashmap_size * features float16
    table_size = levels * hashmap_size * features
    hash_tables = np.frombuffer(data[offset:offset + table_size * 2], dtype=np.float16).astype(np.float32)
    hash_tables = hash_tables.reshape(levels, hashmap_size, features)
    offset += table_size * 2
    
    # MLP weights (transposed format: [in, out])
    mlp_weights = []
    mlp_biases = []
    
    # Hidden layers
    in_dim = mlp_in
    for l in range(mlp_layers):
        out_dim = mlp_hidden
        w_size = in_dim * out_dim
        w = np.frombuffer(data[offset:offset + w_size * 2], dtype=np.float16).astype(np.float32)
        w = w.reshape(in_dim, out_dim)  # Already transposed in file
        offset += w_size * 2
        
        b = np.frombuffer(data[offset:offset + out_dim * 2], dtype=np.float16).astype(np.float32)
        offset += out_dim * 2
        
        mlp_weights.append(w)
        mlp_biases.append(b)
        in_dim = out_dim
    
    # Output layer
    w_size = mlp_hidden * mlp_out
    w = np.frombuffer(data[offset:offset + w_size * 2], dtype=np.float16).astype(np.float32)
    w = w.reshape(mlp_hidden, mlp_out)
    offset += w_size * 2
    
    b = np.frombuffer(data[offset:offset + mlp_out * 2], dtype=np.float16).astype(np.float32)
    offset += mlp_out * 2
    
    mlp_weights.append(w)
    mlp_biases.append(b)
    
    return {
        'levels': levels, 'features': features, 'hashmap_size': hashmap_size,
        'base_res': base_res, 'per_level_scale': per_level_scale,
        'mlp_in': mlp_in, 'mlp_hidden': mlp_hidden, 'mlp_layers': mlp_layers, 'mlp_out': mlp_out,
        'center': np.array([cx, cy, cz]), 'scale': scale,
        'hash_tables': hash_tables, 'weights': mlp_weights, 'biases': mlp_biases
    }

def spatial_hash(x, y, z, size):
    """Same hash as shader."""
    h = (x * 1) ^ (y * 2654435761) ^ (z * 805459861)
    return int(h) & (size - 1)

def hashgrid_embed(p, model):
    """Embed position using hash grid with trilinear interpolation."""
    levels = model['levels']
    features = model['features']
    hashmap_size = model['hashmap_size']
    base_res = model['base_res']
    per_level_scale = model['per_level_scale']
    hash_tables = model['hash_tables']
    
    embed = []
    
    for l in range(levels):
        res = base_res * (per_level_scale ** l)
        grid = p * res
        gi = np.floor(grid).astype(int)
        w = grid - gi  # Interpolation weights
        
        # 8 corners
        corners = []
        for dz in [0, 1]:
            for dy in [0, 1]:
                for dx in [0, 1]:
                    cx, cy, cz = gi[0] + dx, gi[1] + dy, gi[2] + dz
                    h = spatial_hash(cx, cy, cz, hashmap_size)
                    feat = hash_tables[l, h, :]
                    corners.append(feat)
        
        # Trilinear interpolation
        c000, c001, c010, c011, c100, c101, c110, c111 = corners
        wx, wy, wz = w
        
        v0 = c000 * (1-wx) + c100 * wx
        v1 = c010 * (1-wx) + c110 * wx
        v01 = v0 * (1-wy) + v1 * wy
        
        v0 = c001 * (1-wx) + c101 * wx
        v1 = c011 * (1-wx) + c111 * wx
        v11 = v0 * (1-wy) + v1 * wy
        
        val = v01 * (1-wz) + v11 * wz
        embed.extend(val.tolist())
    
    return np.array(embed)

def mlp_forward(embed, view_dir, model):
    """Forward pass through MLP."""
    weights = model['weights']
    biases = model['biases']
    mlp_layers = model['mlp_layers']
    
    # Build input: embedding + view direction [0,1]
    view_norm = view_dir / (np.linalg.norm(view_dir) + 1e-8)
    view_01 = view_norm * 0.5 + 0.5
    
    x = np.concatenate([embed, view_01])
    
    # Hidden layers
    for l in range(mlp_layers):
        x = x @ weights[l] + biases[l]
        x = np.maximum(x, 0)  # ReLU
    
    # Output layer
    x = x @ weights[-1] + biases[-1]
    
    # Activations
    rgb = 1.0 / (1.0 + np.exp(-x[:3]))  # Sigmoid
    sigma = np.log(1.0 + np.exp(x[3]))   # Softplus
    
    return rgb, sigma

def render_ray(ro, rd, model, steps=64, t_near=0.1, t_far=6.0, density_scale=1.0):
    """Volume render a single ray."""
    center = model['center']
    scale = model['scale']
    
    step_size = (t_far - t_near) / steps
    
    col = np.zeros(3)
    trans = 1.0
    
    for i in range(steps):
        t = t_near + (i + 0.5) * step_size
        p_world = ro + rd * t
        
        # Transform to local [-1, 1]
        p_local = (p_world - center) / scale
        
        # Check bounds
        if np.any(p_local < -1) or np.any(p_local > 1):
            continue
        
        # Transform to [0, 1] for embedding
        p_norm = p_local * 0.5 + 0.5
        p_norm = np.clip(p_norm, 0, 1)
        
        # Evaluate NeRF
        embed = hashgrid_embed(p_norm, model)
        rgb, sigma = mlp_forward(embed, rd, model)
        
        # Volume rendering
        sigma_scaled = sigma * density_scale * step_size
        alpha = 1.0 - np.exp(-sigma_scaled)
        
        col += trans * alpha * rgb
        trans *= (1.0 - alpha)
        
        if trans < 0.01:
            break
    
    return col

def main():
    import sys
    model_path = sys.argv[1] if len(sys.argv) > 1 else "models/lego_nerf.bin"
    
    model = load_nerf_model(model_path)
    
    W, H = 200, 150
    fov = 50.0
    aspect = W / H
    
    # Camera at z=4 looking at origin
    cam_pos = np.array([0.0, 0.0, 4.0])
    cam_dir = np.array([0.0, 0.0, -1.0])
    cam_up = np.array([0.0, 1.0, 0.0])
    cam_right = np.cross(cam_dir, cam_up)
    
    focal = 0.5 / np.tan(np.radians(fov) * 0.5)
    
    img = np.zeros((H, W, 3))
    
    print(f"Rendering {W}x{H}...")
    for y in range(H):
        if y % 20 == 0:
            print(f"  Row {y}/{H}")
        for x in range(W):
            u = (x + 0.5) / W - 0.5
            v = (y + 0.5) / H - 0.5
            
            rd = cam_dir * focal + cam_right * u * aspect - cam_up * v
            rd = rd / np.linalg.norm(rd)
            
            col = render_ray(cam_pos, rd, model, steps=64, t_near=0.1, t_far=8.0, density_scale=1.0)
            img[y, x] = col
    
    img = np.clip(img * 255, 0, 255).astype(np.uint8)
    Image.fromarray(img).save("cpu_nerf_reference.png")
    
    # Stats
    nonzero = (img > 0).sum()
    print(f"Non-zero pixels: {nonzero} / {img.size} ({100*nonzero/img.size:.1f}%)")
    print(f"Mean: {img.mean():.1f}, Max: {img.max()}")
    print("Saved cpu_nerf_reference.png")

if __name__ == "__main__":
    main()
