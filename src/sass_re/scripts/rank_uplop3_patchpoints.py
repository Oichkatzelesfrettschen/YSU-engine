#!/usr/bin/env python3
"""
Rank local ULOP3/PLOP3 patch candidates against mined library UPLOP3 motifs.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re


INSTR_RE = re.compile(r"/\*[0-9a-f]+\*/\s+([A-Z0-9_.]+)")


def load_library_uplop3_motifs(root: pathlib.Path) -> collections.Counter[tuple[str, ...]]:
    motifs: collections.Counter[tuple[str, ...]] = collections.Counter()
    for path in sorted(root.rglob("UPLOP3_LUT_*.txt")):
        ops = []
        for line in path.read_text(encoding="utf-8").splitlines():
            m = INSTR_RE.search(line)
            if m:
                ops.append(m.group(1))
        try:
            idx = ops.index("UPLOP3.LUT")
        except ValueError:
            continue
        motif = tuple(ops[max(0, idx - 3): min(len(ops), idx + 4)])
        motifs[motif] += 1
    return motifs


def extract_local_candidates(path: pathlib.Path) -> list[tuple[str, tuple[str, ...]]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    ops = []
    for line in lines:
        m = INSTR_RE.search(line)
        if m:
            ops.append(m.group(1))
    out = []
    for idx, op in enumerate(ops):
        if op not in {"ULOP3.LUT", "PLOP3.LUT"}:
            continue
        motif = tuple(ops[max(0, idx - 3): min(len(ops), idx + 4)])
        out.append((op, motif))
    return out


def jaccard(a: tuple[str, ...], b: tuple[str, ...]) -> float:
    sa = set(a)
    sb = set(b)
    if not sa and not sb:
        return 1.0
    return len(sa & sb) / len(sa | sb)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library-indir", required=True)
    parser.add_argument("--outdir", required=True)
    parser.add_argument("locals", nargs="+")
    args = parser.parse_args()

    motifs = load_library_uplop3_motifs(pathlib.Path(args.library_indir))
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    lines = ["uplop3_patchpoint_rankings", "=========================", ""]
    top_library = motifs.most_common(8)
    lines.append("Top library UPLOP3 motifs:")
    for motif, count in top_library:
        lines.append(f"- {count}x {' -> '.join(motif)}")
    lines.append("")

    for local_s in args.locals:
        path = pathlib.Path(local_s)
        lines.append(f"{path}:")
        candidates = extract_local_candidates(path)
        if not candidates:
            lines.append("- no local ULOP3/PLOP3 candidates")
            lines.append("")
            continue
        scored = []
        for op, motif in candidates:
            best = 0.0
            best_lib = ()
            best_count = 0
            for lib_motif, count in top_library:
                score = jaccard(motif, lib_motif)
                if score > best:
                    best = score
                    best_lib = lib_motif
                    best_count = count
            scored.append((best, op, motif, best_count, best_lib))
        scored.sort(reverse=True)
        for best, op, motif, best_count, best_lib in scored[:8]:
            lines.append(f"- {op} score={best:.3f}")
            lines.append(f"  local: {' -> '.join(motif)}")
            lines.append(f"  best lib ({best_count}x): {' -> '.join(best_lib)}")
        lines.append("")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
