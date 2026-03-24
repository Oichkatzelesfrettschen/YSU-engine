#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re


INST_RE = re.compile(r"/\*.*?\*/\s+([A-Z0-9_.]+)")


def ops_from_lines(lines: list[str]) -> list[str]:
    ops: list[str] = []
    for line in lines:
        m = INST_RE.search(line)
        if m:
            ops.append(m.group(1))
    return ops


def load_library_motifs(root: pathlib.Path) -> list[tuple[pathlib.Path, list[str]]]:
    motifs: list[tuple[pathlib.Path, list[str]]] = []
    for path in sorted(root.rglob("UPLOP3_LUT_*.txt")):
        ops = ops_from_lines(path.read_text().splitlines())
        if "UPLOP3.LUT" in ops:
            motifs.append((path, ops))
    return motifs


def local_window(path: pathlib.Path, radius: int = 3) -> list[str]:
    lines = path.read_text().splitlines()
    ops = ops_from_lines(lines)
    for i, op in enumerate(ops):
        if op == "UPLOP3.LUT":
            lo = max(0, i - radius)
            hi = min(len(ops), i + radius + 1)
            return ops[lo:hi]
    raise SystemExit(f"no UPLOP3.LUT in {path}")


def jaccard(a: list[str], b: list[str]) -> float:
    sa = set(a)
    sb = set(b)
    return len(sa & sb) / len(sa | sb) if sa or sb else 1.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library-root", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("locals", nargs="+", help="label=path")
    args = parser.parse_args()

    motifs = load_library_motifs(pathlib.Path(args.library_root))
    lines = ["live_uplop3_context_rankings", "===========================", ""]
    for entry in args.locals:
        label, path_str = entry.split("=", 1)
        path = pathlib.Path(path_str)
        lw = local_window(path)
        best = None
        for lib_path, motif in motifs:
            score = jaccard(lw, motif)
            if best is None or score > best[0]:
                best = (score, lib_path, motif)
        assert best is not None
        lines.append(f"context={label}")
        lines.append(f"- local_path={path}")
        lines.append(f"- local_window={' -> '.join(lw)}")
        lines.append(f"- best_jaccard={best[0]:.6f}")
        lines.append(f"- best_library_path={best[1]}")
        lines.append(f"- best_library_window={' -> '.join(best[2])}")
        lines.append("")

    out_path = pathlib.Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
