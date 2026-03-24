#!/usr/bin/env python3
"""
Compare bitfield deltas among plain P2R, P2R.B2, P2R.B3, and R2P exemplars.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re


LINE_RE = re.compile(r"(P2R(?:\.B[23])?|R2P)[^/]+/\*\s*(0x[0-9a-fA-F]+)\s*\*/")
CTRL_RE = re.compile(r"/\*\s*(0x[0-9a-fA-F]+)\s*\*/")


def collect(path: pathlib.Path, needles: tuple[str, ...]) -> list[tuple[str, int, int]]:
    out = []
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    for i, line in enumerate(lines):
        if not any(n in line for n in needles):
            continue
        m = LINE_RE.search(line)
        if not m or i + 1 >= len(lines):
            continue
        c = CTRL_RE.search(lines[i + 1])
        if not c:
            continue
        out.append((m.group(1), int(m.group(2), 16), int(c.group(1), 16)))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library-b2", required=True)
    parser.add_argument("--library-b3", required=True)
    parser.add_argument("--local", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    lib_b2 = collect(pathlib.Path(args.library_b2), ("P2R.B2", "R2P"))
    lib_b3 = collect(pathlib.Path(args.library_b3), ("P2R.B3", "P2R.B2"))
    local = collect(pathlib.Path(args.local), ("P2R ",))

    rows = []
    plain = next((x for x in local if x[0] == "P2R"), None)
    b2 = next((x for x in lib_b2 if x[0] == "P2R.B2"), None)
    r2p = next((x for x in lib_b2 if x[0] == "R2P"), None)
    b3 = next((x for x in lib_b3 if x[0] == "P2R.B3"), None)
    if plain and b2:
        rows.append({
            "compare": "plain_to_b2",
            "word0_xor": f"0x{plain[1] ^ b2[1]:016x}",
            "word1_xor": f"0x{plain[2] ^ b2[2]:016x}",
        })
    if plain and b3:
        rows.append({
            "compare": "plain_to_b3",
            "word0_xor": f"0x{plain[1] ^ b3[1]:016x}",
            "word1_xor": f"0x{plain[2] ^ b3[2]:016x}",
        })
    if b2 and b3:
        rows.append({
            "compare": "b2_to_b3",
            "word0_xor": f"0x{b2[1] ^ b3[1]:016x}",
            "word1_xor": f"0x{b2[2] ^ b3[2]:016x}",
        })
    if b2 and r2p:
        rows.append({
            "compare": "b2_to_r2p",
            "word0_xor": f"0x{b2[1] ^ r2p[1]:016x}",
            "word1_xor": f"0x{b2[2] ^ r2p[2]:016x}",
        })

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / "bitfields.json").write_text(json.dumps({
        "plain": plain, "b2": b2, "b3": b3, "r2p": r2p, "deltas": rows
    }, indent=2), encoding="utf-8")
    summary = ["p2r_bitfields", "=============", ""]
    summary.append(f"- plain: {plain}")
    summary.append(f"- b2: {b2}")
    summary.append(f"- b3: {b3}")
    summary.append(f"- r2p: {r2p}")
    summary.append("- deltas:")
    for row in rows:
        summary.append(f"  - {row['compare']}: word0_xor={row['word0_xor']} word1_xor={row['word1_xor']}")
    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
