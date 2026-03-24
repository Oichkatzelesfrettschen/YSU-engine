#!/usr/bin/env python3
"""
Summarize richer B2/B3 motif pockets from mined library P2R windows.
"""

from __future__ import annotations

import argparse
import pathlib
from dataclasses import dataclass


TOKENS = ("LDS.64", "BAR.SYNC", "ULDC", "R2P", "P2R.B2", "P2R.B3", "LDGSTS")


@dataclass
class WindowHit:
    score: int
    path: pathlib.Path
    text: str


def score_window(text: str) -> int:
    return sum(token in text for token in TOKENS)


def collect_hits(root: pathlib.Path, needle: str, limit: int) -> list[WindowHit]:
    hits: list[WindowHit] = []
    for path in sorted(root.glob(f"{needle}_*.txt")):
        text = path.read_text(encoding="utf-8")
        score = score_window(text)
        if score:
            hits.append(WindowHit(score=score, path=path, text=text))
    hits.sort(key=lambda hit: (-hit.score, hit.path.name))
    return hits[:limit]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--windows-root", required=True)
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--limit", type=int, default=8)
    args = parser.parse_args()

    root = pathlib.Path(args.windows_root)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary_lines = [
        "library_p2r_motifs",
        "==================",
        "",
        f"- windows_root: {root}",
        f"- tokens: {', '.join(TOKENS)}",
        "",
    ]

    for needle in ("P2R_B2", "P2R_B3"):
        summary_lines.append(f"{needle}:")
        hits = collect_hits(root, needle, args.limit)
        if not hits:
            summary_lines.append("- no hits")
            summary_lines.append("")
            continue
        for idx, hit in enumerate(hits, start=1):
            rel = hit.path.name
            summary_lines.append(f"- #{idx}: {rel} score={hit.score}")
            summary_lines.append(f"  tokens: {', '.join(token for token in TOKENS if token in hit.text)}")
            excerpt_path = outdir / f"{needle.lower()}_{idx}.txt"
            excerpt_path.write_text(hit.text + "\n", encoding="utf-8")
        summary_lines.append("")

    (outdir / "summary.txt").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
