#!/usr/bin/env python3
"""
Instant-NGP style NeRF training with nerfacc acceleration.
Much faster than vanilla NeRF - trains in minutes instead of hours.

Exports to YSU shader format (hashgrid + MLP weights).
"""

import argparse
import json
import math
import os
import struct
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from pathlib import Path

# nerfacc for occupancy grid and ray marching acceleration
HAS_NERFACC = False
try:
    import nerfacc
    from nerfacc import OccGridEstimator
    # Test if nerfacc CUDA is actually working
    nerfacc.cuda._C  # This will be None if CUDA toolkit not found
    if nerfacc.cuda._C is not None:
        HAS_NERFACC = True
    else:
        print("[WARNING] nerfacc CUDA not available, using vanilla ray marching")
except (ImportError, AttributeError):
    print("[WARNING] nerfacc not available, using vanilla ray marching")


def positional_encoding(x, L=4):
    """Positional encoding for coordinates."""
    freqs = 2.0 ** torch.linspace(0, L - 1, L, device=x.device)
    x_freq = x[..., None] * freqs
    return torch.cat([x, torch.sin(x_freq).flatten(-2), torch.cos(x_freq).flatten(-2)], dim=-1)


class HashEncoding(nn.Module):
    """
    Multi-resolution hash encoding (instant-ngp style).
    Uses the same hash function as our GPU shader for compatibility.
    """
    def __init__(self, num_levels=16, features_per_level=2, log2_hashmap_size=19, 
                 base_resolution=16, per_level_scale=1.5, bounds=1.5):
        super().__init__()
        self.num_levels = num_levels
        self.features_per_level = features_per_level
        self.hashmap_size = 2 ** log2_hashmap_size
        self.base_resolution = base_resolution
        self.per_level_scale = per_level_scale
        self.bounds = bounds
        
        # Hash table for each level
        self.hash_tables = nn.ParameterList([
            nn.Parameter(torch.randn(self.hashmap_size, features_per_level) * 0.0001)
            for _ in range(num_levels)
        ])
        
        # Precompute resolutions for each level
        self.resolutions = [
            int(base_resolution * (per_level_scale ** level))
            for level in range(num_levels)
        ]
        
    def hash_coords(self, coords):
        """
        Hash 3D integer coordinates to table index.
        Uses same primes as GPU shader: (73856093, 19349663, 83492791)
        MUST match original training script exactly!
        """
        # coords: [N, 3] integer coordinates
        x = coords[..., 0]
        y = coords[..., 1]
        z = coords[..., 2]
        # Exact same formula as original training script:
        return (x * 73856093 ^ y * 19349663 ^ z * 83492791) % self.hashmap_size
    
    def forward(self, x):
        """
        x: [N, 3] positions already normalized to [0, 1] range
        (caller must do: x_norm = (x - center) / scale * 0.5 + 0.5)
        returns: [N, num_levels * features_per_level]
        """
        # Input already in [0, 1]
        x_norm = torch.clamp(x, 0.0, 1.0 - 1e-6)
        
        features = []
        for level, resolution in enumerate(self.resolutions):
            # Scale to grid
            x_scaled = x_norm * resolution
            
            # Get corner indices
            x_floor = x_scaled.floor().long()
            x_ceil = x_floor + 1
            
            # Interpolation weights
            w = x_scaled - x_scaled.floor()
            
            # All 8 corners of the voxel
            corners = []
            weights = []
            for i in range(2):
                for j in range(2):
                    for k in range(2):
                        corner = torch.stack([
                            x_floor[..., 0] if i == 0 else x_ceil[..., 0],
                            x_floor[..., 1] if j == 0 else x_ceil[..., 1],
                            x_floor[..., 2] if k == 0 else x_ceil[..., 2],
                        ], dim=-1)
                        corners.append(corner)
                        
                        # Trilinear weight
                        weight = (
                            ((1 - w[..., 0]) if i == 0 else w[..., 0]) *
                            ((1 - w[..., 1]) if j == 0 else w[..., 1]) *
                            ((1 - w[..., 2]) if k == 0 else w[..., 2])
                        )
                        weights.append(weight)
            
            # Gather and interpolate
            level_features = torch.zeros(x.shape[0], self.features_per_level, device=x.device)
            for corner, weight in zip(corners, weights):
                idx = self.hash_coords(corner)
                corner_features = self.hash_tables[level][idx]
                level_features = level_features + weight.unsqueeze(-1) * corner_features
            
            features.append(level_features)
        
        return torch.cat(features, dim=-1)


class InstantNGPNeRF(nn.Module):
    """
    Instant-NGP style NeRF with hash encoding.
    Uses single MLP architecture to match GPU shader.
    Input: hash_embedding (levels * features) + view_dir (3) -> rgb (3) + sigma (1)
    """
    def __init__(self, num_levels=16, features_per_level=2, log2_hashmap_size=19,
                 base_resolution=16, per_level_scale=1.5, hidden_dim=64, 
                 num_layers=2, bounds=1.5):
        super().__init__()
        
        self.bounds = bounds
        self.hash_encoding = HashEncoding(
            num_levels=num_levels,
            features_per_level=features_per_level,
            log2_hashmap_size=log2_hashmap_size,
            base_resolution=base_resolution,
            per_level_scale=per_level_scale,
            bounds=bounds
        )
        
        # Input: hash embedding + view direction (3)
        # This matches the original training script and GPU shader
        hash_dim = num_levels * features_per_level
        mlp_in = hash_dim + 3  # hash + view_dir
        
        # Single MLP: (hash + view) -> hidden layers -> (rgb + sigma)
        layers = []
        dim = mlp_in
        for _ in range(num_layers):
            layers.append(nn.Linear(dim, hidden_dim))
            layers.append(nn.ReLU(inplace=True))
            dim = hidden_dim
        layers.append(nn.Linear(dim, 4))  # rgb (3) + sigma (1)
        self.mlp = nn.Sequential(*layers)
        
        self.hidden_dim = hidden_dim
        self.num_levels = num_levels
        self.features_per_level = features_per_level
        self.log2_hashmap_size = log2_hashmap_size
        self.base_resolution = base_resolution
        self.per_level_scale = per_level_scale
        self.num_layers = num_layers
        self.mlp_in = mlp_in
        
    def forward(self, x, d):
        """
        x: [N, 3] positions
        d: [N, 3] view directions (normalized)
        returns: rgb [N, 3], sigma [N, 1]
        """
        # Hash encoding for position
        h = self.hash_encoding(x)
        
        # Concatenate hash embedding + view direction (matching original training script)
        inp = torch.cat([h, d], dim=-1)
        
        # Single MLP forward pass
        out = self.mlp(inp)
        
        # Activations: sigmoid for RGB, softplus for sigma (with offset like original)
        # Original script outputs RGB directly - no BGR swap needed
        rgb = torch.sigmoid(out[..., :3])
        sigma = F.softplus(out[..., 3:4] - 1.0)
        
        return rgb, sigma
    
    def density(self, x):
        """Get density only (for occupancy grid)."""
        h = self.hash_encoding(x)
        # Use zero view direction for density-only query
        d = torch.zeros_like(x)
        inp = torch.cat([h, d], dim=-1)
        out = self.mlp(inp)
        sigma = F.softplus(out[..., 3:4] - 1.0)
        return sigma


def load_nerf_synthetic(data_dir, split='train', scale=1.0):
    """Load NeRF synthetic dataset."""
    transforms_file = os.path.join(data_dir, f'transforms_{split}.json')
    with open(transforms_file, 'r') as f:
        meta = json.load(f)
    
    images = []
    poses = []
    
    camera_angle_x = meta['camera_angle_x']
    
    for frame in meta['frames']:
        # Load image
        img_path = os.path.join(data_dir, frame['file_path'] + '.png')
        img = Image.open(img_path).convert('RGBA')
        
        if scale != 1.0:
            new_size = (int(img.width * scale), int(img.height * scale))
            img = img.resize(new_size, Image.LANCZOS)
        
        img = np.array(img) / 255.0
        
        # Composite alpha
        rgb = img[..., :3] * img[..., 3:4] + (1 - img[..., 3:4])
        images.append(rgb)
        
        # Camera pose
        pose = np.array(frame['transform_matrix'])
        poses.append(pose)
    
    images = np.stack(images, axis=0).astype(np.float32)
    poses = np.stack(poses, axis=0).astype(np.float32)
    
    H, W = images.shape[1:3]
    focal = 0.5 * W / np.tan(0.5 * camera_angle_x)
    
    return images, poses, H, W, focal


def get_rays(H, W, focal, c2w):
    """Generate rays for a camera pose."""
    device = c2w.device
    
    i, j = torch.meshgrid(
        torch.arange(W, device=device),
        torch.arange(H, device=device),
        indexing='xy'
    )
    
    # Camera coordinates
    dirs = torch.stack([
        (i - W * 0.5) / focal,
        -(j - H * 0.5) / focal,
        -torch.ones_like(i)
    ], dim=-1)
    
    # World coordinates
    rays_d = (dirs[..., None, :] * c2w[:3, :3]).sum(-1)
    rays_o = c2w[:3, 3].expand(rays_d.shape)
    
    return rays_o.reshape(-1, 3), rays_d.reshape(-1, 3)


def render_rays(model, rays_o, rays_d, near=0.0, far=6.0, n_samples=64, 
                occupancy_grid=None, device='cuda', scene_center=None, scene_scale=1.0):
    """Render rays using volume rendering."""
    
    # Normalize directions
    rays_d_norm = rays_d / rays_d.norm(dim=-1, keepdim=True)
    
    # Scene normalization: (p - center) / scale * 0.5 + 0.5 -> [0, 1]
    if scene_center is None:
        scene_center = torch.zeros(3, device=device)
    else:
        scene_center = torch.tensor(scene_center, device=device, dtype=torch.float32)
    
    def normalize_pos(pts):
        """Normalize positions to [0, 1] range for hash encoding."""
        p_local = (pts - scene_center) / scene_scale
        p_norm = p_local * 0.5 + 0.5
        return torch.clamp(p_norm, 0.0, 1.0)
    
    if HAS_NERFACC and occupancy_grid is not None:
        # Use nerfacc for accelerated ray marching
        def sigma_fn(t_starts, t_ends, ray_indices):
            t_mid = (t_starts + t_ends) / 2.0
            positions = rays_o[ray_indices] + t_mid * rays_d_norm[ray_indices]
            positions_norm = normalize_pos(positions)
            return model.density(positions_norm).squeeze(-1)
        
        def rgb_sigma_fn(t_starts, t_ends, ray_indices):
            t_mid = (t_starts + t_ends) / 2.0
            positions = rays_o[ray_indices] + t_mid * rays_d_norm[ray_indices]
            positions_norm = normalize_pos(positions)
            directions = rays_d_norm[ray_indices]
            rgb, sigma = model(positions_norm, directions)
            return rgb, sigma.squeeze(-1)
        
        # Ray marching with occupancy grid
        ray_indices, t_starts, t_ends = occupancy_grid.sampling(
            rays_o, rays_d_norm,
            sigma_fn=sigma_fn,
            near_plane=near, far_plane=far,
            render_step_size=1e-2,
            stratified=model.training,
        )
        
        # Volume rendering
        rgb, sigma = rgb_sigma_fn(t_starts, t_ends, ray_indices)
        
        # Accumulate
        weights, trans, alphas = nerfacc.render_weight_from_density(
            t_starts, t_ends, sigma, ray_indices=ray_indices, n_rays=rays_o.shape[0]
        )
        rgb_map = nerfacc.accumulate_along_rays(
            weights, values=rgb, ray_indices=ray_indices, n_rays=rays_o.shape[0]
        )
        acc_map = nerfacc.accumulate_along_rays(
            weights, values=None, ray_indices=ray_indices, n_rays=rays_o.shape[0]
        )
        
        # White background
        rgb_map = rgb_map + (1 - acc_map.unsqueeze(-1))
        
        return rgb_map
    else:
        # Fallback: uniform sampling
        t_vals = torch.linspace(near, far, n_samples, device=device)
        t_vals = t_vals.unsqueeze(0).expand(rays_o.shape[0], -1)
        
        # Add noise during training
        if model.training:
            mids = 0.5 * (t_vals[..., 1:] + t_vals[..., :-1])
            upper = torch.cat([mids, t_vals[..., -1:]], dim=-1)
            lower = torch.cat([t_vals[..., :1], mids], dim=-1)
            t_vals = lower + (upper - lower) * torch.rand_like(t_vals)
        
        # Sample points
        pts = rays_o.unsqueeze(1) + rays_d_norm.unsqueeze(1) * t_vals.unsqueeze(-1)
        pts_norm = normalize_pos(pts.reshape(-1, 3))
        dirs_flat = rays_d_norm.unsqueeze(1).expand_as(pts).reshape(-1, 3)
        
        # Query network
        rgb, sigma = model(pts_norm, dirs_flat)
        rgb = rgb.reshape(rays_o.shape[0], n_samples, 3)
        sigma = sigma.reshape(rays_o.shape[0], n_samples)
        
        # Volume rendering
        dists = t_vals[..., 1:] - t_vals[..., :-1]
        dists = torch.cat([dists, torch.ones_like(dists[..., :1]) * 0.1], dim=-1)
        
        alpha = 1.0 - torch.exp(-sigma * dists)
        
        T = torch.cumprod(torch.cat([
            torch.ones_like(alpha[..., :1]),
            1.0 - alpha + 1e-10
        ], dim=-1), dim=-1)[..., :-1]
        
        weights = alpha * T
        rgb_map = (weights.unsqueeze(-1) * rgb).sum(dim=1)
        acc_map = weights.sum(dim=1)
        
        # White background
        rgb_map = rgb_map + (1 - acc_map.unsqueeze(-1))
        
        return rgb_map


def export_model(model, out_hashgrid, out_occ, scene_center, scene_scale):
    """Export model to YSU shader format."""
    print(f"\n[EXPORT] Saving to {out_hashgrid}")
    
    with torch.no_grad():
        # Collect hash table data
        hash_tables = []
        for table in model.hash_encoding.hash_tables:
            hash_tables.append(table.cpu().numpy())
        
        # Get MLP weights from single MLP
        mlp_weights = []
        for layer in model.mlp:
            if isinstance(layer, nn.Linear):
                mlp_weights.append((layer.weight.cpu().numpy(), layer.bias.cpu().numpy()))
    
    # Write binary format
    hashmap_size = model.hash_encoding.hashmap_size
    mlp_in = model.mlp_in  # levels * features + 3 (view dir)
    
    # Expected header format from gpu_vulkan_demo.c:
    # typedef struct NerfHashGridHeader {
    #     uint32_t magic;           // 0x3147484E 'NHG1'
    #     uint32_t version;         // 2
    #     uint32_t levels;
    #     uint32_t features;
    #     uint32_t hashmap_size;
    #     uint32_t base_resolution;
    #     float    per_level_scale;
    #     uint32_t mlp_in;          // input dim (levels * features + 3)
    #     uint32_t mlp_hidden;
    #     uint32_t mlp_layers;      // 2
    #     uint32_t mlp_out;         // 4 (rgb + sigma)
    #     uint32_t flags;           // scene_scale stored as float bits
    #     uint32_t reserved[3];     // center x, y, z as float bits
    # } NerfHashGridHeader;  // 60 bytes total
    
    with open(out_hashgrid, 'wb') as f:
        NERF_HASHGRID_MAGIC = 0x3147484E  # 'NHG1'
        
        # Pack center and scale as uint32 (bit representation of float)
        cx_bits = struct.unpack('I', struct.pack('f', scene_center[0]))[0]
        cy_bits = struct.unpack('I', struct.pack('f', scene_center[1]))[0]
        cz_bits = struct.unpack('I', struct.pack('f', scene_center[2]))[0]
        scale_bits = struct.unpack('I', struct.pack('f', scene_scale))[0]
        
        header = struct.pack('IIIIIIfIIIIIIII',
            NERF_HASHGRID_MAGIC,           # magic
            2,                              # version
            model.num_levels,               # levels
            model.features_per_level,       # features
            hashmap_size,                   # hashmap_size
            model.base_resolution,          # base_resolution
            model.per_level_scale,          # per_level_scale (float)
            mlp_in,                         # mlp_in (hash + view_dir)
            model.hidden_dim,               # mlp_hidden
            model.num_layers,               # mlp_layers
            4,                              # mlp_out (rgb + sigma)
            scale_bits,                     # flags (scene_scale as float bits)
            cx_bits,                        # reserved[0] (center_x)
            cy_bits,                        # reserved[1] (center_y)
            cz_bits,                        # reserved[2] (center_z)
        )
        f.write(header)
        
        # Hash tables (fp16)
        for table in hash_tables:
            table_fp16 = table.astype(np.float16)
            f.write(table_fp16.tobytes())
        
        # MLP weights (transposed for column-major access, fp16)
        for w, b in mlp_weights:
            w_T = w.T.astype(np.float16)  # Transpose [out, in] -> [in, out]
            b_fp16 = b.astype(np.float16)
            f.write(w_T.tobytes())
            f.write(b_fp16.tobytes())
    
    # Export occupancy grid
    print(f"[EXPORT] Saving occupancy grid to {out_occ}")
    
    with torch.no_grad():
        # Sample occupancy grid in [0, 1] normalized space
        grid_res = 128
        # Generate grid in [0, 1] range to match hash encoding input
        coords = torch.stack(torch.meshgrid(
            torch.linspace(0.0, 1.0, grid_res),
            torch.linspace(0.0, 1.0, grid_res),
            torch.linspace(0.0, 1.0, grid_res),
            indexing='ij'
        ), dim=-1).reshape(-1, 3).cuda()
        
        # Batch evaluation
        densities = []
        batch_size = 65536
        for i in range(0, coords.shape[0], batch_size):
            batch = coords[i:i+batch_size]
            sigma = model.density(batch)
            densities.append(sigma.cpu().numpy())
        
        densities = np.concatenate(densities, axis=0).reshape(grid_res, grid_res, grid_res)
        
        # Threshold to binary
        threshold = 0.01
        occupancy = (densities > threshold).astype(np.uint8)
    
    # Expected header format from gpu_vulkan_demo.c:
    # typedef struct NerfOccHeader {
    #     uint32_t magic;      // 0x31474F4E 'NOG1'
    #     uint32_t dim;
    #     float    scale;
    #     float    threshold;
    # } NerfOccHeader;  // 16 bytes
    
    with open(out_occ, 'wb') as f:
        NERF_OCC_MAGIC = 0x31474F4E  # 'NOG1'
        header = struct.pack('IIff', 
            NERF_OCC_MAGIC,
            grid_res,
            model.bounds * 2,  # scale = full box size
            threshold
        )
        f.write(header)
        f.write(occupancy.tobytes())
    
    print(f"[EXPORT] Done! Hash grid: {os.path.getsize(out_hashgrid)/1024/1024:.1f} MB")


def main():
    parser = argparse.ArgumentParser(description='Instant-NGP style NeRF training')
    parser.add_argument('--data', type=str, required=True, help='Path to NeRF synthetic dataset')
    parser.add_argument('--out_hashgrid', type=str, default='models/instant_nerf.bin')
    parser.add_argument('--out_occ', type=str, default='models/instant_occ.bin')
    parser.add_argument('--iters', type=int, default=20000, help='Training iterations')
    parser.add_argument('--batch_rays', type=int, default=8192)
    parser.add_argument('--lr', type=float, default=1e-2, help='Learning rate')
    parser.add_argument('--levels', type=int, default=16)
    parser.add_argument('--log2_hashmap', type=int, default=19, help='Log2 of hashmap size')
    parser.add_argument('--hidden', type=int, default=64)
    parser.add_argument('--base_res', type=int, default=16)
    parser.add_argument('--per_level_scale', type=float, default=1.5)
    parser.add_argument('--scale', type=float, default=0.5, help='Image scale for faster training')
    args = parser.parse_args()
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"[INSTANT-NGP] Device: {device}")
    print(f"[INSTANT-NGP] nerfacc available: {HAS_NERFACC}")
    
    # Load data
    print(f"[INSTANT-NGP] Loading {args.data}...")
    images, poses, H, W, focal = load_nerf_synthetic(args.data, scale=args.scale)
    print(f"[INSTANT-NGP] Loaded {len(images)} images, {W}x{H}, focal={focal:.1f}")
    
    images = torch.from_numpy(images).to(device)
    poses = torch.from_numpy(poses).to(device)
    
    # Scene bounds (NeRF synthetic is centered at origin)
    scene_center = np.array([0.0, 0.0, 0.0])
    scene_scale = 1.5
    near, far = 2.0, 6.0
    
    # Create model
    model = InstantNGPNeRF(
        num_levels=args.levels,
        features_per_level=2,
        log2_hashmap_size=args.log2_hashmap,
        base_resolution=args.base_res,
        per_level_scale=args.per_level_scale,
        hidden_dim=args.hidden,
        bounds=scene_scale
    ).to(device)
    
    print(f"[INSTANT-NGP] Model: {args.levels} levels, 2^{args.log2_hashmap} hashmap, {args.hidden} hidden")
    
    # Optimizer - same LR for all params (matching original training script)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr, eps=1e-15)
    
    scheduler = torch.optim.lr_scheduler.ExponentialLR(optimizer, gamma=0.9999)
    
    # Occupancy grid for acceleration (if nerfacc available)
    occupancy_grid = None
    if HAS_NERFACC:
        occupancy_grid = OccGridEstimator(
            roi_aabb=torch.tensor([-scene_scale, -scene_scale, -scene_scale, 
                                    scene_scale, scene_scale, scene_scale], device=device),
            resolution=128,
            levels=1
        )
    
    # Training loop
    print(f"\n[INSTANT-NGP] Training for {args.iters} iterations...")
    
    n_images = len(images)
    
    for step in range(1, args.iters + 1):
        model.train()
        
        # Random image and rays
        img_idx = torch.randint(0, n_images, (1,)).item()
        rays_o, rays_d = get_rays(H, W, focal, poses[img_idx])
        
        # Random ray batch
        ray_indices = torch.randint(0, H * W, (args.batch_rays,), device=device)
        rays_o_batch = rays_o[ray_indices]
        rays_d_batch = rays_d[ray_indices]
        
        target = images[img_idx].reshape(-1, 3)[ray_indices]
        
        # Update occupancy grid periodically
        if HAS_NERFACC and occupancy_grid is not None and step % 16 == 0:
            def occ_eval_fn(x):
                return model.density(x).squeeze(-1)
            occupancy_grid.update_every_n_steps(
                step=step, occ_eval_fn=occ_eval_fn, occ_thre=0.01
            )
        
        # Render
        rgb = render_rays(model, rays_o_batch, rays_d_batch, 
                         near=near, far=far, n_samples=96,  # Match original
                         occupancy_grid=occupancy_grid, device=device,
                         scene_center=scene_center, scene_scale=scene_scale)
        
        # Loss
        loss = F.mse_loss(rgb, target)
        
        # Backward
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        scheduler.step()
        
        # Log
        if step % 100 == 0 or step == 1:
            psnr = -10 * math.log10(loss.item())
            lr = optimizer.param_groups[0]['lr']
            print(f"iter {step}/{args.iters} loss={loss.item():.6f} PSNR={psnr:.2f}dB lr={lr:.6f}")
        
        # Save checkpoint
        if step % 5000 == 0:
            export_model(model, args.out_hashgrid, args.out_occ, scene_center, scene_scale)
    
    # Final export
    model.eval()
    export_model(model, args.out_hashgrid, args.out_occ, scene_center, scene_scale)
    print(f"\n[INSTANT-NGP] Training complete!")


if __name__ == '__main__':
    main()
# kill me -later