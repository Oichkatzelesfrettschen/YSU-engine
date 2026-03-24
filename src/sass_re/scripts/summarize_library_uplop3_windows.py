#!/usr/bin/env python3
"""
Summarize dominant library UPLOP3/ULOP3/PLOP3 window motifs.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re


INSTR_RE = re.compile(r"/\*[0-9a-f]+\*/\s+([A-Z0-9_.]+)")
FOCUS = ("UPLOP3.LUT", "ULOP3.LUT", "PLOP3.LUT")


def load_windows(root: pathlib.Path) -> list[tuple[pathlib.Path, str]]:
    windows: list[tuple[pathlib.Path, str]] = []
    for path in sorted(root.rglob("*.txt")):
        if path.name == "summary.txt":
            continue
        text = path.read_text(encoding="utf-8")
        windows.append((path, text))
    return windows


def classify_window(text: str) -> tuple[str, tuple[str, ...]]:
    ops = []
    for line in text.splitlines():
        m = INSTR_RE.search(line)
        if m:
            ops.append(m.group(1))
    focus_idx = next((i for i, op in enumerate(ops) if op in FOCUS), None)
    if focus_idx is None:
        return ("NO_FOCUS", tuple(ops[:6]))
    start = max(0, focus_idx - 3)
    end = min(len(ops), focus_idx + 4)
    motif = tuple(ops[start:end])
    return (ops[focus_idx], motif)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--indir", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    indir = pathlib.Path(args.indir)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    counts: dict[str, collections.Counter[tuple[str, ...]]] = {
        focus: collections.Counter() for focus in FOCUS
    }
    examples: dict[tuple[str, tuple[str, ...]], pathlib.Path] = {}
    totals = {focus: 0 for focus in FOCUS}

    for path, text in load_windows(indir):
        focus, motif = classify_window(text)
        if focus not in counts:
            continue
        counts[focus][motif] += 1
        totals[focus] += 1
        examples.setdefault((focus, motif), path)

    lines = ["library_uplop3_window_summary", "=============================", ""]
    for focus in FOCUS:
        lines.append(f"{focus}:")
        lines.append(f"- total: {totals[focus]}")
        if totals[focus] == 0:
            lines.append("- none")
            lines.append("")
            continue
        for motif, count in counts[focus].most_common(12):
            motif_s = " -> ".join(motif)
            example = examples[(focus, motif)]
            lines.append(f"- {count}x {motif_s}")
            lines.append(f"  example: {example}")
        lines.append("")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
