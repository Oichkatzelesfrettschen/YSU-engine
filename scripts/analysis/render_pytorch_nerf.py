"""
Render a test image using PyTorch NeRF model loaded from binary.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from PIL import Image
import struct
from pathlib import Path


class HashGridEncoder(nn.Module):
    def __init__(self, levels, features, hashmap_size, base_res, per_level_scale):
        super().__init__()
        self.levels = levels
        self.features = features
        self.hashmap_size = hashmap_size
        self.base_res = base_res
        self.per_level_scale = per_level_scale
        self.tables = nn.ParameterList([
            nn.Parameter(torch.randn(hashmap_size, features) * 0.01)
            for _ in range(levels)
        ])

    def hash_coords(self, coords):
        x = coords[..., 0]
        y = coords[..., 1]
        z = coords[..., 2]
        return (x * 73856093 ^ y * 19349663 ^ z * 83492791) % self.hashmap_size

    def forward(self, x):
        # x is (N, 3) in [0, 1]
        embeds = []
        for l in range(self.levels):
            res = int(self.base_res * (self.per_level_scale ** l))
            pos = x * res
            pos_floor = torch.floor(pos).long()
            pos_ceil = pos_floor + 1
            w = pos - pos_floor.float()
            
            # 8 corners
            c000 = self.hash_coords(pos_floor)
            c001 = self.hash_coords(torch.stack([pos_floor[...,0], pos_floor[...,1], pos_ceil[...,2]], dim=-1))
            c010 = self.hash_coords(torch.stack([pos_floor[...,0], pos_ceil[...,1], pos_floor[...,2]], dim=-1))
            c011 = self.hash_coords(torch.stack([pos_floor[...,0], pos_ceil[...,1], pos_ceil[...,2]], dim=-1))
            c100 = self.hash_coords(torch.stack([pos_ceil[...,0], pos_floor[...,1], pos_floor[...,2]], dim=-1))
            c101 = self.hash_coords(torch.stack([pos_ceil[...,0], pos_floor[...,1], pos_ceil[...,2]], dim=-1))
            c110 = self.hash_coords(torch.stack([pos_ceil[...,0], pos_ceil[...,1], pos_floor[...,2]], dim=-1))
            c111 = self.hash_coords(torch.stack([pos_ceil[...,0], pos_ceil[...,1], pos_ceil[...,2]], dim=-1))

            table = self.tables[l]
            v000 = table[c000]
            v001 = table[c001]
            v010 = table[c010]
            v011 = table[c011]
            v100 = table[c100]
            v101 = table[c101]
            v110 = table[c110]
            v111 = table[c111]

            # Trilinear interpolation
            w_x = w[..., 0:1]; w_y = w[..., 1:2]; w_z = w[..., 2:3]
            v00 = v000 * (1 - w_z) + v001 * w_z
            v01 = v010 * (1 - w_z) + v011 * w_z
            v10 = v100 * (1 - w_z) + v101 * w_z
            v11 = v110 * (1 - w_z) + v111 * w_z
            
            v0 = v00 * (1 - w_y) + v01 * w_y
            v1 = v10 * (1 - w_y) + v11 * w_y
            
            emb = v0 * (1 - w_x) + v1 * w_x
            embeds.append(emb)
        return torch.cat(embeds, dim=-1)


class NerfMLP(nn.Module):
    def __init__(self, in_dim, hidden, layers, out_dim):
        super().__init__()
        mlp = []
        dim = in_dim
        for _ in range(layers):
            mlp.append(nn.Linear(dim, hidden))
            mlp.append(nn.ReLU())
            dim = hidden
        mlp.append(nn.Linear(dim, out_dim))
        self.net = nn.Sequential(*mlp)

    def forward(self, x):
        return self.net(x)


class NerfModel(nn.Module):
    def __init__(self, levels, features, hashmap_size, base_res, per_level_scale, hidden, layers):
        super().__init__()
        self.enc = HashGridEncoder(levels, features, hashmap_size, base_res, per_level_scale)
        in_dim = levels * features + 3
        self.mlp = NerfMLP(in_dim, hidden, layers, 4)

    def forward(self, x, view_dir):
        h = self.enc(x)
        h = torch.cat([h, view_dir], dim=-1)
        out = self.mlp(h)
        rgb = torch.sigmoid(out[..., :3])
        sigma = F.relu(out[..., 3:4])
        return rgb, sigma


def load_binary_model(path):
    """Load binary model and return components."""
    with open(path, 'rb') as f:
        header = struct.unpack('<15I', f.read(60))
        magic, version, levels, features, hashmap_size, base_res = header[:6]
        per_level_scale = struct.unpack('<f', struct.pack('<I', header[6]))[0]
        mlp_in, mlp_hidden, mlp_layers, mlp_out = header[7:11]
        scale = struct.unpack('<f', struct.pack('<I', header[11]))[0]
        cx = struct.unpack('<f', struct.pack('<I', header[12]))[0]
        cy = struct.unpack('<f', struct.pack('<I', header[13]))[0]
        cz = struct.unpack('<f', struct.pack('<I', header[14]))[0]
        
        tables = []
        for l in range(levels):
            table_data = np.frombuffer(f.read(hashmap_size * features * 2), dtype=np.float16)
            tables.append(table_data.reshape(hashmap_size, features).astype(np.float32))
        
        mlp_weights = []
        in_dim = mlp_in
        for layer_idx in range(mlp_layers):
            out_dim = mlp_hidden
            w_size = in_dim * out_dim
            w = np.frombuffer(f.read(w_size * 2), dtype=np.float16).astype(np.float32)
            w = w.reshape(in_dim, out_dim).T
            b = np.frombuffer(f.read(out_dim * 2), dtype=np.float16).astype(np.float32)
            mlp_weights.append((w, b))
            in_dim = out_dim
        
        out_dim = mlp_out
        w_size = mlp_hidden * out_dim
        w = np.frombuffer(f.read(w_size * 2), dtype=np.float16).astype(np.float32)
        w = w.reshape(mlp_hidden, out_dim).T
        b = np.frombuffer(f.read(out_dim * 2), dtype=np.float16).astype(np.float32)
        mlp_weights.append((w, b))
        
        return {
            'levels': levels,
            'features': features,
            'hashmap_size': hashmap_size,
            'base_res': base_res,
            'per_level_scale': per_level_scale,
            'mlp_hidden': mlp_hidden,
            'mlp_layers': mlp_layers,
            'scale': scale,
            'center': np.array([cx, cy, cz]),
            'tables': tables,
            'mlp_weights': mlp_weights
        }


def create_model_from_binary(data):
    """Create PyTorch model from binary data."""
    model = NerfModel(
        levels=data['levels'],
        features=data['features'],
        hashmap_size=data['hashmap_size'],
        base_res=data['base_res'],
        per_level_scale=data['per_level_scale'],
        hidden=data['mlp_hidden'],
        layers=data['mlp_layers']
    )
    
    for l, table in enumerate(data['tables']):
        model.enc.tables[l].data = torch.from_numpy(table)
    
    linear_idx = 0
    for module in model.mlp.net:
        if isinstance(module, nn.Linear):
            w, b = data['mlp_weights'][linear_idx]
            module.weight.data = torch.from_numpy(w)
            module.bias.data = torch.from_numpy(b)
            linear_idx += 1
    
    return model


def volume_render(rgb, sigma, t_vals):
    """Volume render with alpha compositing."""
    dists = t_vals[..., 1:] - t_vals[..., :-1]
    dists = torch.cat([dists, 1e10 * torch.ones_like(dists[..., :1])], dim=-1)
    
    alpha = 1.0 - torch.exp(-sigma[..., 0] * dists)
    trans = torch.cumprod(1.0 - alpha + 1e-10, dim=-1)
    trans = torch.cat([torch.ones_like(trans[..., :1]), trans[..., :-1]], dim=-1)
    weights = alpha * trans
    
    rgb_map = (weights[..., None] * rgb).sum(dim=-2)
    return rgb_map


def main():
    bin_path = Path("models/nerf_hashgrid.bin")
    if not bin_path.exists():
        print(f"Error: {bin_path} not found")
        return
    
    print("Loading binary model...")
    data = load_binary_model(bin_path)
    model = create_model_from_binary(data)
    model.eval()
    
    center = torch.tensor(data['center'], dtype=torch.float32)
    scale = data['scale']
    
    # Render a test image
    W, H = 256, 256
    n_samples = 64
    t_near, t_far = 0.5, 4.0
    
    # Camera setup - simple front view
    cam_pos = torch.tensor([center[0].item() - 3.0, center[1].item(), center[2].item()], dtype=torch.float32)
    cam_forward = torch.tensor([1.0, 0.0, 0.0], dtype=torch.float32)
    cam_right = torch.tensor([0.0, 0.0, 1.0], dtype=torch.float32)
    cam_up = torch.tensor([0.0, 1.0, 0.0], dtype=torch.float32)
    
    print(f"Rendering {W}x{H} image...")
    print(f"Camera: pos={cam_pos.tolist()}, center={center.tolist()}, scale={scale}")
    
    pixels = []
    for y in range(H):
        if y % 32 == 0:
            print(f"  Row {y}/{H}")
        row_pixels = []
        for x in range(W):
            u = (x + 0.5) / W
            v = (y + 0.5) / H
            
            # Ray direction (simple perspective)
            fov = 0.8
            dx = (u - 0.5) * fov
            dy = (0.5 - v) * fov  # flip Y
            ray_d = cam_forward + dx * cam_right + dy * cam_up
            ray_d = ray_d / torch.norm(ray_d)
            
            # Sample points along ray
            t_vals = torch.linspace(t_near, t_far, n_samples)
            pts = cam_pos + ray_d * t_vals.unsqueeze(-1)
            
            # Normalize
            pts_norm = (pts - center) / scale
            pts_norm = pts_norm * 0.5 + 0.5
            pts_norm = torch.clamp(pts_norm, 0, 1)
            
            view = ray_d.unsqueeze(0).expand(n_samples, 3)
            
            with torch.no_grad():
                rgb, sigma = model(pts_norm, view)
            
            # Volume render
            rgb_map = volume_render(rgb, sigma, t_vals)
            row_pixels.append(rgb_map.squeeze().numpy())
        
        pixels.append(row_pixels)
    
    # Save image
    pixels = np.array(pixels)
    pixels = np.clip(pixels * 255, 0, 255).astype(np.uint8)
    img = Image.fromarray(pixels)
    img.save("pytorch_nerf_render.png")
    print(f"Saved pytorch_nerf_render.png")
    print(f"Image stats: min={pixels.min()}, max={pixels.max()}, mean={pixels.mean():.1f}")


if __name__ == "__main__":
    main()
