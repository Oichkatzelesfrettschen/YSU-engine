import argparse
import json
import math
import os
import struct
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

import torch
import torch.nn as nn
import torch.nn.functional as F


@dataclass
class TrainConfig:
    data_root: Path
    out_hashgrid: Path
    out_occ: Path
    device: str
    iters: int
    batch_rays: int
    n_samples: int
    lr: float
    levels: int
    features: int
    hashmap_size: int
    base_res: int
    per_level_scale: float
    hidden: int
    layers: int
    occ_dim: int
    occ_threshold: float


def load_transforms(path: Path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    camera_angle_x = data.get("camera_angle_x", None)
    if camera_angle_x is None:
        raise ValueError("transforms.json missing camera_angle_x")
    frames = data["frames"]
    return camera_angle_x, frames


def load_images(image_dir: Path, frames):
    images = []
    poses = []
    missing = 0
    for fr in frames:
        file_path = fr["file_path"]
        # Try both .png and .jpg if no extension specified
        img_path = (image_dir / file_path).resolve()
        if not img_path.exists() and not (file_path.lower().endswith(".jpg") or file_path.lower().endswith(".png")):
            if (image_dir / (file_path + ".png")).exists():
                file_path += ".png"
            else:
                file_path += ".jpg"
        
        img_path = (image_dir / file_path).resolve()
        if not img_path.exists():
            # try direct file name
            img_path = (image_dir / Path(file_path).name).resolve()
        if not img_path.exists():
            missing += 1
            continue
        img = Image.open(img_path).convert("RGB")
        images.append(np.array(img).astype(np.float32) / 255.0)
        poses.append(np.array(fr["transform_matrix"], dtype=np.float32))
    if missing > 0:
        print(f"[NERF] warning: skipped {missing} missing images")
    if len(images) == 0:
        raise RuntimeError("No images found in dataset")
    return np.stack(images, axis=0), np.stack(poses, axis=0)


def get_rays(H, W, focal, c2w):
    i, j = np.meshgrid(np.arange(W), np.arange(H), indexing="xy")
    dirs = np.stack([(i - W * 0.5) / focal, -(j - H * 0.5) / focal, -np.ones_like(i)], axis=-1)
    # rotate
    rays_d = (dirs[..., None, :] * c2w[None, None, :3, :3]).sum(-1)
    rays_o = np.broadcast_to(c2w[:3, 3], rays_d.shape)
    return rays_o, rays_d


def estimate_scene_bounds(poses, H, W, focal, near, far, stride=16, max_frames=8):
    # Sample a subset of rays and estimate bounds at near/far to derive center/scale
    total = poses.shape[0]
    if total == 0:
        return np.zeros(3, dtype=np.float32), 1.0
    idx = np.linspace(0, total - 1, num=min(max_frames, total), dtype=int)
    bmin = np.array([np.inf, np.inf, np.inf], dtype=np.float32)
    bmax = np.array([-np.inf, -np.inf, -np.inf], dtype=np.float32)
    for i in idx:
        ro, rd = get_rays(H, W, focal, poses[i])
        ro_s = ro[::stride, ::stride].reshape(-1, 3)
        rd_s = rd[::stride, ::stride].reshape(-1, 3)
        p0 = ro_s + rd_s * near
        p1 = ro_s + rd_s * far
        pts = np.concatenate([p0, p1], axis=0)
        bmin = np.minimum(bmin, pts.min(axis=0))
        bmax = np.maximum(bmax, pts.max(axis=0))
    center = (bmin + bmax) * 0.5
    extent = (bmax - bmin) * 0.5
    scale = float(np.max(extent))
    if scale <= 1e-6:
        scale = 1.0
    return center.astype(np.float32), scale


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
        # coords: (..., 3) int32
        x = coords[..., 0]
        y = coords[..., 1]
        z = coords[..., 2]
        # spatial hash
        return (x * 73856093 ^ y * 19349663 ^ z * 83492791) % self.hashmap_size

    def forward(self, x):
        # x: (..., 3) in [0,1]
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
            mlp.append(nn.ReLU(inplace=True))
            dim = hidden
        mlp.append(nn.Linear(dim, out_dim))
        self.net = nn.Sequential(*mlp)

    def forward(self, x):
        return self.net(x)


class NerfModel(nn.Module):
    def __init__(self, cfg: TrainConfig):
        super().__init__()
        self.enc = HashGridEncoder(cfg.levels, cfg.features, cfg.hashmap_size, cfg.base_res, cfg.per_level_scale)
        in_dim = cfg.levels * cfg.features + 3
        self.mlp = NerfMLP(in_dim, cfg.hidden, cfg.layers, 4)

    def forward(self, x, view_dir):
        # x in [0,1], view_dir normalized
        h = self.enc(x)
        h = torch.cat([h, view_dir], dim=-1)
        out = self.mlp(h)
        rgb = torch.sigmoid(out[..., :3])
        sigma = F.relu(out[..., 3:4])
        return rgb, sigma


def volume_render(rgb, sigma, t_vals):
    # rgb: [B, N, 3], sigma: [B, N, 1], t_vals: [B, N]
    dists = t_vals[..., 1:] - t_vals[..., :-1]
    dists = torch.cat([dists, 1e10 * torch.ones_like(dists[..., :1])], dim=-1)
    alpha = 1.0 - torch.exp(-sigma.squeeze(-1) * dists)
    T = torch.cumprod(torch.cat([torch.ones_like(alpha[..., :1]), 1.0 - alpha + 1e-10], dim=-1), dim=-1)[..., :-1]
    weights = alpha * T
    rgb_map = (weights[..., None] * rgb).sum(dim=-2)
    return rgb_map, weights


def export_hashgrid(cfg: TrainConfig, model: NerfModel, center, scale):
    header = struct.pack(
        "<15I",
        0x3147484E,  # 'NHG1'
        2,
        cfg.levels,
        cfg.features,
        cfg.hashmap_size,
        cfg.base_res,
        struct.unpack("<I", struct.pack("<f", float(cfg.per_level_scale)))[0],
        cfg.levels * cfg.features + 3,
        cfg.hidden,
        cfg.layers,
        4,
        struct.unpack("<I", struct.pack("<f", float(scale)))[0],
        struct.unpack("<I", struct.pack("<f", float(center[0])))[0],
        struct.unpack("<I", struct.pack("<f", float(center[1])))[0],
        struct.unpack("<I", struct.pack("<f", float(center[2])))[0],
    )

    with open(cfg.out_hashgrid, "wb") as f:
        f.write(header)
        # hash tables
        for table in model.enc.tables:
            data = table.detach().cpu().half().numpy()
            f.write(data.tobytes())
        # mlp weights: TRANSPOSE [out,in]->[in,out] for correct GPU inference
        # PyTorch stores as [out_neurons, in_features], but GPU shader expects column-major
        for m in model.mlp.net:
            if isinstance(m, nn.Linear):
                w = m.weight.detach().cpu().half().numpy()  # [out, in]
                w_t = w.T.copy()  # [in, out] - transposed and contiguous
                b = m.bias.detach().cpu().half().numpy()
                f.write(w_t.tobytes())
                f.write(b.tobytes())


def export_occupancy(cfg: TrainConfig, model: NerfModel, device):
    N = cfg.occ_dim
    # grid in [-1,1] -> [0,1]
    coords = torch.linspace(0.0, 1.0, N, device=device)
    xv, yv, zv = torch.meshgrid(coords, coords, coords, indexing="ij")
    pts = torch.stack([xv, yv, zv], dim=-1).view(-1, 3)
    view = torch.tensor([0.0, 0.0, -1.0], device=device).view(1, 3).repeat(pts.shape[0], 1)
    with torch.no_grad():
        _, sigma = model(pts, view)
        sigma_flat = sigma.view(-1)
    sigma_np = sigma_flat.detach().cpu().numpy()
    thr = float(cfg.occ_threshold)
    if thr <= 0.0:
        thr = float(np.percentile(sigma_np, 90) * 0.2)
        thr = max(thr, 1e-6)
    occ = (sigma_np > thr).astype(np.uint8)
    if occ.sum() == 0 and sigma_np.max() > 0.0:
        thr = float(sigma_np.max() * 0.01)
        occ = (sigma_np > thr).astype(np.uint8)
    if occ.sum() == 0:
        thr = 0.0
        occ = (sigma_np >= 0.0).astype(np.uint8)
    occ_ratio = float(occ.mean())
    print(f"[NERF] occ stats: sigma_min={sigma_np.min():.6f} sigma_max={sigma_np.max():.6f} sigma_mean={sigma_np.mean():.6f} thr={thr:.6f} occ_ratio={occ_ratio:.6f}")
    header = struct.pack("<IIff", 0x31474F4E, N, 2.0 / N, thr)
    with open(cfg.out_occ, "wb") as f:
        f.write(header)
        f.write(occ.tobytes())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--data", default="DataNeRF/data/nerf/fox")
    p.add_argument("--out_hashgrid", default="models/nerf_hashgrid.bin")
    p.add_argument("--out_occ", default="models/occupancy_grid.bin")
    p.add_argument("--iters", type=int, default=2000)
    p.add_argument("--batch_rays", type=int, default=1024)
    p.add_argument("--n_samples", type=int, default=32)
    p.add_argument("--lr", type=float, default=1e-2)
    p.add_argument("--levels", type=int, default=12)
    p.add_argument("--features", type=int, default=2)
    p.add_argument("--hashmap_size", type=int, default=8192)
    p.add_argument("--base_res", type=int, default=16)
    p.add_argument("--per_level_scale", type=float, default=1.5)
    p.add_argument("--hidden", type=int, default=64)
    p.add_argument("--layers", type=int, default=2)
    p.add_argument("--occ_dim", type=int, default=64)
    p.add_argument("--occ_threshold", type=float, default=1.0)
    args = p.parse_args()

    cfg = TrainConfig(
        data_root=Path(args.data),
        out_hashgrid=Path(args.out_hashgrid),
        out_occ=Path(args.out_occ),
        device="cuda" if torch.cuda.is_available() else "cpu",
        iters=args.iters,
        batch_rays=args.batch_rays,
        n_samples=args.n_samples,
        lr=args.lr,
        levels=args.levels,
        features=args.features,
        hashmap_size=args.hashmap_size,
        base_res=args.base_res,
        per_level_scale=args.per_level_scale,
        hidden=args.hidden,
        layers=args.layers,
        occ_dim=args.occ_dim,
        occ_threshold=args.occ_threshold,
    )

    transforms = cfg.data_root / "transforms.json"
    images_dir = cfg.data_root
    camera_angle_x, frames = load_transforms(transforms)
    imgs, poses = load_images(images_dir, frames)
    H, W = imgs.shape[1], imgs.shape[2]
    focal = 0.5 * W / math.tan(0.5 * camera_angle_x)

    device = torch.device(cfg.device)
    model = NerfModel(cfg).to(device)
    optim = torch.optim.Adam(model.parameters(), lr=cfg.lr)

    # Precompute rays for all frames
    all_rays_o = []
    all_rays_d = []
    for i in range(len(poses)):
        ro, rd = get_rays(H, W, focal, poses[i])
        all_rays_o.append(ro)
        all_rays_d.append(rd)
    all_rays_o = np.stack(all_rays_o, axis=0)
    all_rays_d = np.stack(all_rays_d, axis=0)

    print(f"[NERF] device={cfg.device} images={len(poses)} size={W}x{H}")

    t_near, t_far = 0.5, 4.0
    center, scale = estimate_scene_bounds(poses, H, W, focal, t_near, t_far)
    print(f"[NERF] scene bounds center={center.tolist()} scale={scale:.4f}")

    for it in range(cfg.iters):
        # sample random image + pixels
        img_idx = np.random.randint(0, len(poses))
        xs = np.random.randint(0, W, size=(cfg.batch_rays,))
        ys = np.random.randint(0, H, size=(cfg.batch_rays,))
        rays_o = all_rays_o[img_idx, ys, xs]
        rays_d = all_rays_d[img_idx, ys, xs]
        target = imgs[img_idx, ys, xs]

        rays_o = torch.from_numpy(rays_o.astype(np.float32)).to(device)
        rays_d = torch.from_numpy(rays_d.astype(np.float32)).to(device)
        rays_d = rays_d / torch.norm(rays_d, dim=-1, keepdim=True)
        target = torch.from_numpy(target.astype(np.float32)).to(device)

        # sample points along ray (near/far fixed)
        t_vals = torch.linspace(t_near, t_far, cfg.n_samples, device=device)
        t_vals = t_vals.unsqueeze(0).expand(cfg.batch_rays, cfg.n_samples)
        pts = rays_o[:, None, :] + rays_d[:, None, :] * t_vals[..., None]

        # normalize to [0,1] using estimated scene center/scale
        pts_norm = (pts - torch.from_numpy(center).to(device)) / scale
        pts_norm = pts_norm * 0.5 + 0.5
        pts_norm = torch.clamp(pts_norm, 0.0, 1.0)
        view = rays_d[:, None, :].expand_as(pts)

        rgb, sigma = model(pts_norm.reshape(-1, 3), view.reshape(-1, 3))
        rgb = rgb.view(cfg.batch_rays, cfg.n_samples, 3)
        sigma = sigma.view(cfg.batch_rays, cfg.n_samples, 1)

        rgb_map, _ = volume_render(rgb, sigma, t_vals)
        loss = F.mse_loss(rgb_map, target)

        optim.zero_grad()
        loss.backward()
        optim.step()

        if (it + 1) % 100 == 0:
            print(f"iter {it+1}/{cfg.iters} loss={loss.item():.6f}")

    cfg.out_hashgrid.parent.mkdir(parents=True, exist_ok=True)
    export_hashgrid(cfg, model, center, scale)
    export_occupancy(cfg, model, device)
    print(f"[NERF] exported: {cfg.out_hashgrid} and {cfg.out_occ}")


if __name__ == "__main__":
    main()
