#!/usr/bin/env python3
"""
Summarize mined library P2R.B* windows into opcode-frequency tables.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re


OP_RE = re.compile(r"/\*[^*]+\*/\s+([A-Z][A-Z0-9_.]*)")


def ops_from_text(text: str) -> list[str]:
    ops = []
    for line in text.splitlines():
        m = OP_RE.search(line)
        if m:
            ops.append(m.group(1))
    return ops


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("window_root")
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.window_root)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    grouped: dict[str, collections.Counter[str]] = {
        "P2R_B1": collections.Counter(),
        "P2R_B2": collections.Counter(),
        "P2R_B3": collections.Counter(),
    }
    counts = {k: 0 for k in grouped}

    for key in grouped:
        for path in sorted(root.rglob(f"{key}_*.txt")):
            counts[key] += 1
            grouped[key].update(ops_from_text(path.read_text(encoding="utf-8", errors="ignore")))

    lines = ["library_p2r_window_summary", "==========================", ""]
    lines.append(f"root={root}")
    lines.append("")

    for key in ("P2R_B1", "P2R_B2", "P2R_B3"):
        lines.append(f"{key}: windows={counts[key]}")
        for op, n in grouped[key].most_common(20):
            lines.append(f"- {op}: {n}")
        lines.append("")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
