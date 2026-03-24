#!/usr/bin/env python3
"""
Mine installed library cubins for P2R.B* windows.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess


NEEDLES = ("P2R.B1", "P2R.B2", "P2R.B3")


def detect_arch(path: pathlib.Path) -> str:
    name = path.name
    if "sm89" in name or "sm_89" in name:
        return "sm_89"
    if "sm86" in name or "sm_86" in name:
        return "sm_86"
    if "cudnn" in name:
        return "sm_86"
    return "sm_89"


def dump_sass(cuobjdump: str, lib: pathlib.Path, arch: str) -> str:
    result = subprocess.run(
        [cuobjdump, "-arch", arch, "-sass", str(lib)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"cuobjdump failed for {lib}")
    return result.stdout


def extract_windows(text: str, radius: int = 10) -> dict[str, list[str]]:
    lines = text.splitlines()
    out: dict[str, list[str]] = {needle: [] for needle in NEEDLES}
    for i, line in enumerate(lines):
        for needle in NEEDLES:
            if needle in line:
                block = lines[max(0, i - radius): min(len(lines), i + radius + 1)]
                out[needle].append("\n".join(block))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--cuobjdump", default="cuobjdump")
    parser.add_argument("libs", nargs="+")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary_lines = ["library_p2r_windows", "===================", ""]
    total_hits = {needle: 0 for needle in NEEDLES}

    for lib_s in args.libs:
        lib = pathlib.Path(lib_s)
        arch = detect_arch(lib)
        entry_dir = outdir / lib.name
        entry_dir.mkdir(parents=True, exist_ok=True)
        try:
            sass = dump_sass(args.cuobjdump, lib, arch)
            (entry_dir / "dump.sass").write_text(sass, encoding="utf-8")
            windows = extract_windows(sass)
            summary_lines.append(f"- {lib} (arch={arch})")
            for needle in NEEDLES:
                count = len(windows[needle])
                total_hits[needle] += count
                summary_lines.append(f"  {needle}: {count}")
                if count:
                    for idx, block in enumerate(windows[needle], start=1):
                        (entry_dir / f"{needle.replace('.', '_')}_{idx}.txt").write_text(
                            block + "\n", encoding="utf-8"
                        )
        except Exception as exc:  # pragma: no cover - diagnostic path
            summary_lines.append(f"- {lib} (arch={arch}) FAILED: {exc}")

    summary_lines.append("")
    summary_lines.append("Totals:")
    for needle in NEEDLES:
        summary_lines.append(f"- {needle}: {total_hits[needle]}")

    (outdir / "summary.txt").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
