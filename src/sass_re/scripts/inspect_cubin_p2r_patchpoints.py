#!/usr/bin/env python3
"""
Rank local plain-P2R patchpoints against mined B2/B3 library motifs.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re


FUNC_RE = re.compile(r"Function : ([A-Za-z0-9_]+)")
OP_RE = re.compile(r"/\*[^*]+\*/\s+(?:@[!P0-9T]+\s+)?([A-Z][A-Z0-9_.]*)")


def read_ops(path: pathlib.Path) -> dict[str, list[str]]:
    funcs: dict[str, list[str]] = {}
    current = None
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = FUNC_RE.search(line)
        if m:
            current = m.group(1)
            funcs[current] = []
            continue
        if current is None:
            continue
        m = OP_RE.search(line)
        if m:
            funcs[current].append(m.group(1))
    return funcs


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sass-glob", required=True)
    parser.add_argument("--seeds", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.seeds).read_text(encoding="utf-8"))
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    refsets: dict[str, set[str]] = {"P2R.B2": set(), "P2R.B3": set()}
    for seed in payload["seeds"]:
        target = seed["target"]
        if target in refsets:
            refsets[target].update(seed["window"])

    rows = []
    seen = set()
    for path in sorted(pathlib.Path().glob(args.sass_glob)):
        funcs = read_ops(path)
        for func, ops in funcs.items():
            opset = set(ops)
            if "P2R" not in opset:
                continue
            key = (func, tuple(sorted(opset)))
            if key in seen:
                continue
            seen.add(key)
            rows.append(
                {
                    "sass": str(path),
                    "function": func,
                    "plain_p2r": ops.count("P2R"),
                    "has_prmt": "PRMT" in opset,
                    "has_bar": any(op.startswith("BAR.SYNC") for op in opset),
                    "has_uldc": any(op.startswith("ULDC") for op in opset),
                    "has_lds": any(op.startswith("LDS") for op in opset),
                    "has_r2p": "R2P" in opset,
                    "b2_jaccard": round(jaccard(opset, refsets["P2R.B2"]), 6),
                    "b3_jaccard": round(jaccard(opset, refsets["P2R.B3"]), 6),
                    "ops": sorted(opset),
                }
            )

    rows.sort(key=lambda r: (max(r["b2_jaccard"], r["b3_jaccard"]), r["plain_p2r"]), reverse=True)
    (outdir / "patchpoints.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")

    summary = ["p2r_patchpoints", "===============", ""]
    for row in rows[:24]:
        summary.append(
            f"- {pathlib.Path(row['sass']).name}:{row['function']}: "
            f"plain_p2r={row['plain_p2r']}, "
            f"b2_jaccard={row['b2_jaccard']}, b3_jaccard={row['b3_jaccard']}, "
            f"bar={row['has_bar']}, uldc={row['has_uldc']}, "
            f"lds={row['has_lds']}, r2p={row['has_r2p']}, prmt={row['has_prmt']}"
        )
    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
