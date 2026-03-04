"""
Validate NeRF inference by comparing PyTorch model with exported binary.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
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
        embeds = []
        for l in range(self.levels):
            res = int(self.base_res * (self.per_level_scale ** l))
            pos = x * res
            pos_floor = torch.floor(pos).int()
            idx = self.hash_coords(pos_floor)
            table = self.tables[l]
            emb = table[idx]
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
        # Read 15 u32 header
        header = struct.unpack('<15I', f.read(60))
        magic, version, levels, features, hashmap_size, base_res = header[:6]
        per_level_scale = struct.unpack('<f', struct.pack('<I', header[6]))[0]
        mlp_in, mlp_hidden, mlp_layers, mlp_out = header[7:11]
        scale = struct.unpack('<f', struct.pack('<I', header[11]))[0]
        cx = struct.unpack('<f', struct.pack('<I', header[12]))[0]
        cy = struct.unpack('<f', struct.pack('<I', header[13]))[0]
        cz = struct.unpack('<f', struct.pack('<I', header[14]))[0]
        
        print(f"Header: magic=0x{magic:08X} version={version}")
        print(f"  levels={levels} features={features} hashmap_size={hashmap_size} base_res={base_res}")
        print(f"  per_level_scale={per_level_scale:.4f}")
        print(f"  mlp: in={mlp_in} hidden={mlp_hidden} layers={mlp_layers} out={mlp_out}")
        print(f"  scale={scale:.4f} center=({cx:.4f}, {cy:.4f}, {cz:.4f})")
        
        # Read hash tables
        tables = []
        for l in range(levels):
            table_data = np.frombuffer(f.read(hashmap_size * features * 2), dtype=np.float16)
            tables.append(table_data.reshape(hashmap_size, features).astype(np.float32))
        
        # Read MLP weights (transposed layout)
        mlp_weights = []
        in_dim = mlp_in
        for layer_idx in range(mlp_layers):
            out_dim = mlp_hidden
            # Weights are stored as [in_dim, out_dim] (transposed)
            w_size = in_dim * out_dim
            w = np.frombuffer(f.read(w_size * 2), dtype=np.float16).astype(np.float32)
            w = w.reshape(in_dim, out_dim)
            # Transpose back to [out_dim, in_dim] for PyTorch
            w = w.T
            
            b = np.frombuffer(f.read(out_dim * 2), dtype=np.float16).astype(np.float32)
            mlp_weights.append((w, b))
            print(f"  Layer {layer_idx}: weight shape={w.shape}, bias shape={b.shape}")
            in_dim = out_dim
        
        # Output layer
        out_dim = mlp_out
        w_size = mlp_hidden * out_dim
        w = np.frombuffer(f.read(w_size * 2), dtype=np.float16).astype(np.float32)
        w = w.reshape(mlp_hidden, out_dim).T
        b = np.frombuffer(f.read(out_dim * 2), dtype=np.float16).astype(np.float32)
        mlp_weights.append((w, b))
        print(f"  Output layer: weight shape={w.shape}, bias shape={b.shape}")
        
        return {
            'levels': levels,
            'features': features,
            'hashmap_size': hashmap_size,
            'base_res': base_res,
            'per_level_scale': per_level_scale,
            'mlp_in': mlp_in,
            'mlp_hidden': mlp_hidden,
            'mlp_layers': mlp_layers,
            'mlp_out': mlp_out,
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
    
    # Load hash tables
    for l, table in enumerate(data['tables']):
        model.enc.tables[l].data = torch.from_numpy(table)
    
    # Load MLP weights
    linear_idx = 0
    for module in model.mlp.net:
        if isinstance(module, nn.Linear):
            w, b = data['mlp_weights'][linear_idx]
            module.weight.data = torch.from_numpy(w)
            module.bias.data = torch.from_numpy(b)
            linear_idx += 1
    
    return model


def main():
    bin_path = Path("models/nerf_hashgrid.bin")
    if not bin_path.exists():
        print(f"Error: {bin_path} not found")
        return
    
    print("=== Loading binary model ===")
    data = load_binary_model(bin_path)
    
    print("\n=== Creating PyTorch model ===")
    model = create_model_from_binary(data)
    model.eval()
    
    # Test inference
    print("\n=== Test inference ===")
    center = data['center']
    scale = data['scale']
    
    # Test points (world space)
    world_pts = torch.tensor([
        [center[0], center[1], center[2]],  # center
        [center[0] + scale * 0.3, center[1], center[2]],  # +x
        [center[0], center[1] + scale * 0.3, center[2]],  # +y
    ], dtype=torch.float32)
    
    # Normalize to [0, 1]
    pts_norm = (world_pts - torch.from_numpy(center)) / scale
    pts_norm = pts_norm * 0.5 + 0.5
    pts_norm = torch.clamp(pts_norm, 0, 1)
    
    view_dir = torch.tensor([[0, 0, -1], [0, 0, -1], [0, 0, -1]], dtype=torch.float32)
    
    print(f"Normalized points:\n{pts_norm}")
    
    with torch.no_grad():
        rgb, sigma = model(pts_norm, view_dir)
    
    print(f"\nModel output:")
    for i in range(len(world_pts)):
        print(f"  Point {i}: RGB=({rgb[i, 0]:.4f}, {rgb[i, 1]:.4f}, {rgb[i, 2]:.4f}), sigma={sigma[i, 0]:.4f}")
    
    # Check hash embedding
    print("\n=== Hash embedding check ===")
    with torch.no_grad():
        embed = model.enc(pts_norm)
    print(f"Embedding shape: {embed.shape}")
    print(f"Embedding stats: min={embed.min():.4f}, max={embed.max():.4f}, mean={embed.mean():.4f}")
    print(f"First 6 embedding values for point 0: {embed[0, :6].tolist()}")
    
    # Check MLP weights
    print("\n=== MLP weight check ===")
    for i, module in enumerate(model.mlp.net):
        if isinstance(module, nn.Linear):
            w = module.weight
            b = module.bias
            print(f"Layer {i}: W min={w.min():.4f}, max={w.max():.4f}, mean={w.mean():.4f}")
            print(f"         B min={b.min():.4f}, max={b.max():.4f}, mean={b.mean():.4f}")


if __name__ == "__main__":
    main()
