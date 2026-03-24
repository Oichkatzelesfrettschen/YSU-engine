#!/usr/bin/env python3
"""
Compile Triton variants and inspect their PTX/SASS for P2R frontier clues.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess

import torch
import triton
import triton.language as tl


def _save_asm(obj, outdir: pathlib.Path, stem: str) -> dict[str, pathlib.Path]:
    saved: dict[str, pathlib.Path] = {}
    asm = getattr(obj, "asm", None)
    if not asm:
        return saved
    for key, value in asm.items():
        suffix = {
            "ttir": ".ttir",
            "ttgir": ".ttgir",
            "llir": ".ll",
            "ptx": ".ptx",
            "cubin": ".cubin",
        }.get(key, f".{key}")
        path = outdir / f"{stem}{suffix}"
        mode = "wb" if isinstance(value, (bytes, bytearray)) else "w"
        with open(path, mode, encoding=None if "b" in mode else "utf-8") as fh:
            fh.write(value)
        saved[key] = path
    return saved


@triton.jit
def kernel_selpack_b1(out_ptr, in_ptr, n_elements, BLOCK: tl.constexpr):
    pid = tl.program_id(0)
    offs = pid * BLOCK + tl.arange(0, BLOCK)
    mask = offs < n_elements
    x = tl.load(in_ptr + offs, mask=mask, other=0)
    p0 = x > 0
    p1 = x < 3
    p2 = x == 7
    p3 = p0 & (~p1)
    a = tl.where(p0, 1, 0)
    b = tl.where(p1, 2, 0)
    c = tl.where(p2, 4, 0)
    d = tl.where(p3, 8, 0)
    y = a + b + c + d
    tl.store(out_ptr + offs, y, mask=mask)


@triton.jit
def kernel_samecarrier_b23(out_ptr, in_ptr, n_elements, BLOCK: tl.constexpr):
    pid = tl.program_id(0)
    offs = pid * BLOCK + tl.arange(0, BLOCK)
    mask = offs < n_elements
    x = tl.load(in_ptr + offs, mask=mask, other=0)
    p0 = x >= 0
    p1 = x >= 16
    p2 = x >= 32
    p3 = x >= 48
    lo = tl.where(p0, 1, 0) + tl.where(p1, 2, 0)
    hi = tl.where(p2, 4, 0) + tl.where(p3, 8, 0)
    y = lo + (hi << 4)
    tl.store(out_ptr + offs, y, mask=mask)


@triton.jit
def kernel_plop3_mix(out_ptr, in_ptr, n_elements, BLOCK: tl.constexpr):
    pid = tl.program_id(0)
    offs = pid * BLOCK + tl.arange(0, BLOCK)
    mask = offs < n_elements
    x = tl.load(in_ptr + offs, mask=mask, other=0)
    p0 = x > 1
    p1 = x < 11
    p2 = (x & 1) == 0
    y = tl.where(p0, x, 0)
    y = y ^ tl.where(p1, 0x33, 0x55)
    y = y + tl.where(p2, 7, 13)
    tl.store(out_ptr + offs, y, mask=mask)


VARIANTS = {
    "triton_selpack_b1": kernel_selpack_b1,
    "triton_samecarrier_b23": kernel_samecarrier_b23,
    "triton_plop3_mix": kernel_plop3_mix,
}


def compile_variant(name: str, kernel, outdir: pathlib.Path, cuobjdump: str) -> str:
    x = torch.arange(256, device="cuda", dtype=torch.int32)
    out = torch.empty_like(x)
    obj = kernel.warmup(out, x, x.numel(), BLOCK=128, grid=(2,))
    saved = _save_asm(obj, outdir, name)
    sass_text = ""
    cubin = saved.get("cubin")
    if cubin and cubin.exists():
        sass_text = subprocess.run(
            [cuobjdump, "-sass", str(cubin)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        (outdir / f"{name}.sass").write_text(sass_text, encoding="utf-8")
    has_byte = any(tag in sass_text for tag in ("P2R.B1", "P2R.B2", "P2R.B3"))
    has_plain = "P2R " in sass_text
    has_plop3 = "PLOP3.LUT" in sass_text
    return f"- {name}: byte_p2r={has_byte}, plain_p2r={has_plain}, plop3={has_plop3}, files={','.join(saved)}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--cuobjdump", default="cuobjdump")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary = ["p2r_triton_search", "=================", ""]
    for name, kernel in VARIANTS.items():
        try:
            summary.append(compile_variant(name, kernel, outdir, args.cuobjdump))
        except Exception as exc:  # pragma: no cover - diagnostic path
            summary.append(f"- {name}: FAIL {exc}")

    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
