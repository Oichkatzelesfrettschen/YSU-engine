#!/usr/bin/env python3
"""
Mine existing .sass text files for instruction windows.
"""

from __future__ import annotations

import argparse
import pathlib


def extract_windows(text: str, needles: tuple[str, ...], radius: int = 10) -> dict[str, list[str]]:
    lines = text.splitlines()
    out: dict[str, list[str]] = {needle: [] for needle in needles}
    for i, line in enumerate(lines):
        for needle in needles:
            if needle in line:
                block = lines[max(0, i - radius): min(len(lines), i + radius + 1)]
                out[needle].append("\n".join(block))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--radius", type=int, default=10)
    parser.add_argument("--needles", nargs="+", required=True)
    parser.add_argument("--inputs", nargs="+", required=True)
    args = parser.parse_args()
    needles = tuple(args.needles)
    inputs = [pathlib.Path(x) for x in args.inputs]

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary_lines = ["sass_text_windows", "=================", ""]
    total_hits = {needle: 0 for needle in needles}

    for path in inputs:
        entry_dir = outdir / path.name
        entry_dir.mkdir(parents=True, exist_ok=True)
        text = path.read_text(encoding="utf-8")
        windows = extract_windows(text, needles, radius=args.radius)
        summary_lines.append(f"- {path}")
        for needle in needles:
            count = len(windows[needle])
            total_hits[needle] += count
            summary_lines.append(f"  {needle}: {count}")
            for idx, block in enumerate(windows[needle], start=1):
                (entry_dir / f"{needle.replace('.', '_')}_{idx}.txt").write_text(
                    block + "\n", encoding="utf-8"
                )

    summary_lines.append("")
    summary_lines.append("Totals:")
    for needle in needles:
        summary_lines.append(f"- {needle}: {total_hits[needle]}")

    (outdir / "summary.txt").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
