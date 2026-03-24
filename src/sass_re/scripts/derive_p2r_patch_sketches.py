#!/usr/bin/env python3
"""
Derive hypothetical B2/B3 patch sketches from local plain-P2R sites.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re


INSN_RE = re.compile(
    r"(?P<pc>/\*[0-9a-f]+\*/)\s+P2R\s+(?P<dst>R\d+), PR, (?P<src>R\d+), (?P<imm>0x[0-9a-fA-F]+)\s*;\s*/\*\s*(?P<word0>0x[0-9a-fA-F]+)\s*\*/"
)
CTRL_RE = re.compile(r"/\*\s*(0x[0-9a-fA-F]+)\s*\*/")


def patch_word(word0: int, new_imm: int) -> int:
    # immediate is in low 32-bit immediate field for these observed P2R encodings
    return (word0 & ~0xFFFFFFFF00000000) | ((new_imm & 0xFFFFFFFF) << 32) | (word0 & 0xFFFFFFFF)


def patch_ctrl(word1: int, lane: str) -> int:
    word1 &= ~0x3000
    if lane == "B2":
        word1 |= 0x2000
    elif lane == "B3":
        word1 |= 0x3000
    return word1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--patchpoints", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    patchpoints = json.loads(pathlib.Path(args.patchpoints).read_text(encoding="utf-8"))
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = []
    for row in patchpoints[:8]:
        sass_path = pathlib.Path(row["sass"])
        lines = sass_path.read_text(encoding="utf-8", errors="ignore").splitlines()
        for idx, line in enumerate(lines):
            m = INSN_RE.search(line)
            if not m:
                continue
            if idx + 1 >= len(lines):
                continue
            c = CTRL_RE.search(lines[idx + 1])
            if not c:
                continue
            word0 = int(m.group("word0"), 16)
            word1 = int(c.group(1), 16)
            for lane, imm in (("B2", 0x78), ("B3", 0x78)):
                rows.append(
                    {
                        "sass": str(sass_path),
                        "function": row["function"],
                        "pc": m.group("pc"),
                        "dst": m.group("dst"),
                        "src": m.group("src"),
                        "orig_imm": m.group("imm"),
                        "orig_word0": f"0x{word0:016x}",
                        "orig_word1": f"0x{word1:016x}",
                        "target_lane": lane,
                        "patched_word0": f"0x{patch_word(word0, imm):016x}",
                        "patched_word1": f"0x{patch_ctrl(word1, lane):016x}",
                    }
                )

    # dedupe by function/pc/lane
    dedup = []
    seen = set()
    for row in rows:
        key = (row["function"], row["pc"], row["target_lane"])
        if key in seen:
            continue
        seen.add(key)
        dedup.append(row)

    (outdir / "patch_sketches.json").write_text(json.dumps(dedup, indent=2), encoding="utf-8")
    summary = ["p2r_patch_sketches", "==================", ""]
    for row in dedup[:24]:
        summary.append(
            f"- {pathlib.Path(row['sass']).name}:{row['function']} {row['pc']} "
            f"{row['dst']}<-{row['src']} lane={row['target_lane']} "
            f"{row['orig_word0']} / {row['orig_word1']} -> "
            f"{row['patched_word0']} / {row['patched_word1']}"
        )
    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
