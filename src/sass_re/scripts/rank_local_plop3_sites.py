#!/usr/bin/env python3
"""
Rank local checked-in PLOP3 sites against a reference neighborhood.
"""

from __future__ import annotations

import argparse
import pathlib
import re


INSTR_RE = re.compile(r"/\*[0-9a-f]+\*/\s+([A-Z0-9_.]+)")
LINE_RE = re.compile(r"/\*[0-9a-f]+\*/\s+PLOP3\.LUT .*?,\s*(0x[0-9a-f]+),\s*0x0", re.IGNORECASE)


def parse_ops(path: pathlib.Path) -> list[tuple[int, str, str]]:
    out = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        m = INSTR_RE.search(line)
        if m:
            out.append((lineno, m.group(1), line))
    return out


def jaccard(a: tuple[str, ...], b: tuple[str, ...]) -> float:
    sa = set(a)
    sb = set(b)
    if not sa and not sb:
        return 1.0
    return len(sa & sb) / len(sa | sb)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", required=True)
    parser.add_argument("--reference-line", type=int, required=True)
    parser.add_argument("--outdir", required=True)
    parser.add_argument("inputs", nargs="+")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    ref_ops = parse_ops(pathlib.Path(args.reference))
    ref_idx = next(i for i, (lineno, _, _) in enumerate(ref_ops) if lineno == args.reference_line)
    ref_motif = tuple(op for _, op, _ in ref_ops[max(0, ref_idx - 3): min(len(ref_ops), ref_idx + 4)])

    rows = []
    for input_s in args.inputs:
        path = pathlib.Path(input_s)
        ops = parse_ops(path)
        for idx, (lineno, op, line) in enumerate(ops):
            if op != "PLOP3.LUT":
                continue
            lm = LINE_RE.search(line)
            imm = lm.group(1).lower() if lm else "unknown"
            motif = tuple(x for _, x, _ in ops[max(0, idx - 3): min(len(ops), idx + 4)])
            score = jaccard(ref_motif, motif)
            rows.append((score, imm, path, lineno, motif))

    rows.sort(reverse=True, key=lambda x: (x[0], x[1], str(x[2]), x[3]))
    lines = ["local_plop3_rankings", "====================", ""]
    lines.append(f"reference: {args.reference}:{args.reference_line}")
    lines.append(f"reference motif: {' -> '.join(ref_motif)}")
    lines.append("")
    for score, imm, path, lineno, motif in rows[:80]:
        lines.append(f"- score={score:.3f} imm={imm} {path}:{lineno}")
        lines.append(f"  {' -> '.join(motif)}")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
