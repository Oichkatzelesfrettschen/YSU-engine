#!/usr/bin/env python3
"""
Instant-NGP style NeRF training for YSU engine.
This version uses the EXACT same training loop as nerf_train_and_export.py
but with instant-NGP style code organization for future enhancements.

Key features for heterogeneous CPU+GPU depth-aware NeRF research:
- Hash grid encoding (matches GPU shader exactly)
- Single MLP architecture
- Compatible with existing GPU shader
- Ready for depth-aware extensions
"""

import argparse
import json
import math
import os
import struct
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image

# Check for nerfacc (optional acceleration)
try:
    import nerfacc
    from nerfacc import OccGridEstimator
    HAS_NERFACC = True
except ImportError:
    HAS_NERFACC = False
    print("[INFO] nerfacc not available, using standard ray marching")


class HashGridEncoder(nn.Module):
    """
    Multi-resolution hash grid encoding (instant-NGP style).
    Matches GPU shader exactly.
    """
    def __init__(self, levels, features, hashmap_size, base_res, per_level_scale):
        super().__init__()
        self.levels = levels
        self.features = features
        self.hashmap_size = hashmap_size
        self.base_res = base_res
        self.per_level_scale = per_level_scale
        
        # Hash tables for each level
        self.tables = nn.ParameterList([
            nn.Parameter(torch.randn(hashmap_size, features) * 0.01)
            for _ in range(levels)
        ])

    def hash_coords(self, coords):
        """Hash 3D integer coordinates - matches GPU shader exactly."""
        x = coords[..., 0]
        y = coords[..., 1]
        z = coords[..., 2]
        return (x * 73856093 ^ y * 19349663 ^ z * 83492791) % self.hashmap_size

    def forward(self, x):
        """
        x: [N, 3] positions in [0, 1] range
        returns: [N, levels * features] hash embedding
        """
        embeds = []
        for l in range(self.levels):
            res = int(self.base_res * (self.per_level_scale ** l))
            pos = x * res
            pos_floor = torch.floor(pos).long()
            pos_ceil = pos_floor + 1
            w = pos - pos_floor.float()
            
            # 8 corners of voxel
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
    """Simple MLP for NeRF - matches GPU shader."""
    def __init__(self, in_dim, hidden, layers, out_dim):
        super().__init__()
        mlp = []
        dim = in_dim
        for _ in range(layers):
            mlp.append(nn.Linear(dim, hidden))
            mlp.append(nn.ReLU(inplace=True))
            dim = hidden
        mlp.append(nn.Linear(dim, out_dim))
        self.net = nn.Sequential(*mlp)

    def forward(self, x):
        return self.net(x)


class InstantNGPNeRF(nn.Module):
    """
    Instant-NGP style NeRF model.
    Architecture: hash_encoding + view_dir -> MLP -> rgb + sigma
    """
    def __init__(self, levels=12, features=2, hashmap_size=8192, 
                 base_res=16, per_level_scale=1.5, hidden=64, layers=2):
        super().__init__()
        self.enc = HashGridEncoder(levels, features, hashmap_size, base_res, per_level_scale)
        in_dim = levels * features + 3  # hash features + view direction
        self.mlp = NerfMLP(in_dim, hidden, layers, 4)  # rgb(3) + sigma(1)
        
        # Store config for export
        self.levels = levels
        self.features = features
        self.hashmap_size = hashmap_size
        self.base_res = base_res
        self.per_level_scale = per_level_scale
        self.hidden = hidden
        self.layers = layers

    def forward(self, x, view_dir):
        """
        x: [N, 3] positions in [0, 1]
        view_dir: [N, 3] normalized view directions
        returns: rgb [N, 3], sigma [N, 1]
        """
        h = self.enc(x)
        h = torch.cat([h, view_dir], dim=-1)
        out = self.mlp(h)
        rgb = torch.sigmoid(out[..., :3])
        sigma = F.softplus(out[..., 3:4] - 1.0)
        return rgb, sigma
    
    def density(self, x):
        """Get density only (for occupancy grid)."""
        h = self.enc(x)
        # Use zero view direction
        d = torch.zeros(x.shape[0], 3, device=x.device)
        h = torch.cat([h, d], dim=-1)
        out = self.mlp(h)
        return F.softplus(out[..., 3:4] - 1.0)


def volume_render(rgb, sigma, t_vals):
    """
    Volume rendering - EXACT copy from original training script.
    """
    dists = t_vals[..., 1:] - t_vals[..., :-1]
    dists = torch.cat([dists, torch.ones_like(dists[..., :1]) * 0.1], dim=-1)
    alpha = 1.0 - torch.exp(-sigma.squeeze(-1) * dists)
    cp = torch.cumprod(1.0 - alpha + 1e-10, dim=-1)
    T = torch.cat([torch.ones_like(cp[..., :1]), cp[..., :-1]], dim=-1)
    weights = alpha * T
    rgb_map = (weights[..., None] * rgb).sum(dim=-2)
    return rgb_map, weights


def get_rays(H, W, focal, c2w):
    """Generate rays - matches original exactly."""
    i, j = np.meshgrid(np.arange(W), np.arange(H), indexing="xy")
    dirs = np.stack([(i - W * 0.5) / focal, -(j - H * 0.5) / focal, -np.ones_like(i)], axis=-1)
    rays_d = (dirs[..., None, :] * c2w[None, None, :3, :3]).sum(-1)
    rays_o = np.broadcast_to(c2w[:3, 3], rays_d.shape)
    return rays_o, rays_d


def load_nerf_synthetic(data_dir):
    """Load NeRF synthetic dataset."""
    transforms_file = os.path.join(data_dir, 'transforms_train.json')
    with open(transforms_file, 'r') as f:
        meta = json.load(f)
    
    camera_angle_x = meta['camera_angle_x']
    images = []
    poses = []
    
    for frame in meta['frames']:
        # Load image
        file_path = frame['file_path']
        img_path = os.path.join(data_dir, file_path)
        if not os.path.exists(img_path):
            img_path = os.path.join(data_dir, file_path + '.png')
        
        img = Image.open(img_path)
        images.append(np.array(img).astype(np.float32) / 255.0)
        poses.append(np.array(frame['transform_matrix'], dtype=np.float32))
    
    images = np.stack(images, axis=0)
    poses = np.stack(poses, axis=0)
    
    H, W = images.shape[1:3]
    focal = 0.5 * W / np.tan(0.5 * camera_angle_x)
    
    print(f"[NERF] loaded {len(images)} images, {W}x{H}, focal={focal:.1f}")
    return images, poses, H, W, focal


def export_model(model, out_hashgrid, out_occ, center, scale, device):
    """Export model to YSU shader format - matches original exactly."""
    
    # Export hash grid
    header = struct.pack(
        "<15I",
        0x3147484E,  # 'NHG1'
        2,  # version
        model.levels,
        model.features,
        model.hashmap_size,
        model.base_res,
        struct.unpack("<I", struct.pack("<f", float(model.per_level_scale)))[0],
        model.levels * model.features + 3,  # mlp_in
        model.hidden,
        model.layers,
        4,  # mlp_out
        struct.unpack("<I", struct.pack("<f", float(scale)))[0],
        struct.unpack("<I", struct.pack("<f", float(center[0])))[0],
        struct.unpack("<I", struct.pack("<f", float(center[1])))[0],
        struct.unpack("<I", struct.pack("<f", float(center[2])))[0],
    )

    with open(out_hashgrid, "wb") as f:
        f.write(header)
        # Hash tables
        for table in model.enc.tables:
            data = table.detach().cpu().half().numpy()
            f.write(data.tobytes())
        # MLP weights: transpose [out, in] -> [in, out] for GPU
        for m in model.mlp.net:
            if isinstance(m, nn.Linear):
                w = m.weight.detach().cpu().half().numpy()  # [out, in]
                w_t = w.T.copy()  # [in, out]
                b = m.bias.detach().cpu().half().numpy()
                f.write(w_t.tobytes())
                f.write(b.tobytes())
    
    # Export occupancy grid
    occ_dim = 64
    occ_threshold = 0.1  # Lower threshold = more voxels marked occupied = fewer holes
    
    coords = torch.linspace(0.0, 1.0, occ_dim, device=device)
    xv, yv, zv = torch.meshgrid(coords, coords, coords, indexing="ij")
    pts = torch.stack([xv, yv, zv], dim=-1).view(-1, 3)
    
    with torch.no_grad():
        sigma = model.density(pts)
    
    sigma_np = sigma.cpu().numpy().reshape(occ_dim, occ_dim, occ_dim)
    occ = (sigma_np > occ_threshold).astype(np.uint8)
    
    occ_header = struct.pack("<IIff", 
        0x31474F4E,  # 'NOG1'
        occ_dim,
        1.0 / occ_dim,
        occ_threshold
    )
    
    with open(out_occ, "wb") as f:
        f.write(occ_header)
        f.write(occ.tobytes())
    
    print(f"[EXPORT] Saved {out_hashgrid} and {out_occ}")


def main():
    parser = argparse.ArgumentParser(description='Instant-NGP NeRF Training')
    parser.add_argument('--data', type=str, required=True, help='Path to NeRF synthetic dataset')
    parser.add_argument('--out_hashgrid', type=str, default='models/instant_nerf.bin')
    parser.add_argument('--out_occ', type=str, default='models/instant_occ.bin')
    parser.add_argument('--iters', type=int, default=5000, help='Training iterations')
    parser.add_argument('--batch_rays', type=int, default=2048, help='Rays per batch')
    parser.add_argument('--n_samples', type=int, default=96, help='Samples per ray')
    parser.add_argument('--lr', type=float, default=2e-3, help='Learning rate')
    parser.add_argument('--levels', type=int, default=12, help='Hash grid levels')
    parser.add_argument('--features', type=int, default=2, help='Features per level')
    parser.add_argument('--hashmap_size', type=int, default=8192, help='Hash table size')
    parser.add_argument('--base_res', type=int, default=16, help='Base resolution')
    parser.add_argument('--per_level_scale', type=float, default=1.5, help='Per-level scale')
    parser.add_argument('--hidden', type=int, default=64, help='MLP hidden dim')
    parser.add_argument('--layers', type=int, default=2, help='MLP layers')
    args = parser.parse_args()
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"[NERF] Device: {device}")
    
    # Load data
    imgs, poses, H, W, focal = load_nerf_synthetic(args.data)
    
    # Precompute all rays (matches original exactly)
    all_rays_o = []
    all_rays_d = []
    for i in range(len(poses)):
        ro, rd = get_rays(H, W, focal, poses[i])
        all_rays_o.append(ro)
        all_rays_d.append(rd)
    all_rays_o = np.stack(all_rays_o, axis=0)
    all_rays_d = np.stack(all_rays_d, axis=0)
    
    print(f"[NERF] images={len(poses)} size={W}x{H}")
    
    # Scene bounds (matches original)
    t_near, t_far = 2.0, 6.0
    center = np.zeros(3, dtype=np.float32)
    scale = 1.5
    print(f"[NERF] scene bounds center={center.tolist()} scale={scale:.4f}")
    
    # Create model
    model = InstantNGPNeRF(
        levels=args.levels,
        features=args.features,
        hashmap_size=args.hashmap_size,
        base_res=args.base_res,
        per_level_scale=args.per_level_scale,
        hidden=args.hidden,
        layers=args.layers
    ).to(device)
    
    # Optimizer (matches original)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    
    center_t = torch.from_numpy(center).to(device)
    
    print(f"\n[NERF] Training for {args.iters} iterations...")
    
    # Training loop - EXACT copy from original
    for it in range(args.iters):
        img_idx = np.random.randint(0, len(poses))
        xs = np.random.randint(0, W, size=(args.batch_rays,))
        ys = np.random.randint(0, H, size=(args.batch_rays,))
        rays_o = all_rays_o[img_idx, ys, xs]
        rays_d = all_rays_d[img_idx, ys, xs]
        target = imgs[img_idx, ys, xs]

        rays_o = torch.from_numpy(rays_o.astype(np.float32)).to(device)
        rays_d = torch.from_numpy(rays_d.astype(np.float32)).to(device)
        rays_d = rays_d / torch.norm(rays_d, dim=-1, keepdim=True)
        target = torch.from_numpy(target.astype(np.float32)).to(device)

        # Handle RGBA
        if target.shape[-1] == 4:
            target_rgb = target[:, :3]
            target_a = target[:, 3:4]
            bg_color = torch.rand(3, device=device)
            target_rgb = target_rgb * target_a + bg_color * (1.0 - target_a)
        else:
            target_rgb = target
            bg_color = None

        t_vals = torch.linspace(t_near, t_far, args.n_samples, device=device)
        t_vals = t_vals.unsqueeze(0).expand(args.batch_rays, args.n_samples)
        pts = rays_o[:, None, :] + rays_d[:, None, :] * t_vals[..., None]

        # Normalize positions (matches original exactly)
        pts_norm = (pts - center_t) / scale
        pts_norm = pts_norm * 0.5 + 0.5
        pts_norm = torch.clamp(pts_norm, 0.0, 1.0)
        view = rays_d[:, None, :].expand_as(pts)

        rgb, sigma = model(pts_norm.reshape(-1, 3), view.reshape(-1, 3))
        rgb = rgb.view(args.batch_rays, args.n_samples, 3)
        sigma = sigma.view(args.batch_rays, args.n_samples, 1)

        rgb_map, weights = volume_render(rgb, sigma, t_vals)
        
        if bg_color is not None:
            acc = weights.sum(dim=-1, keepdim=True)
            rgb_map = rgb_map + bg_color * (1.0 - acc)
            
        loss = F.mse_loss(rgb_map, target_rgb)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        if (it + 1) % 100 == 0:
            psnr = -10 * math.log10(loss.item() + 1e-10)
            print(f"iter {it+1}/{args.iters} loss={loss.item():.6f} PSNR={psnr:.2f}dB")
    
    # Export
    Path(args.out_hashgrid).parent.mkdir(parents=True, exist_ok=True)
    export_model(model, args.out_hashgrid, args.out_occ, center, scale, device)
    print(f"\n[NERF] Training complete!")


if __name__ == '__main__':
    main()
