#!/usr/bin/env python3
"""
Normalize library-side P2R.B* opcode windows and immediate-mask patterns.
"""

from __future__ import annotations

import argparse
import pathlib
import re
from collections import Counter, defaultdict


OP_RE = re.compile(r"/\*[0-9a-f]+\*/\s+(?:@[!P0-9T]+\s+)?([A-Z0-9_.]+)")
HEX_RE = re.compile(r"0x[0-9a-fA-F]+")


def iter_windows(root: pathlib.Path, needle: str):
    for path in sorted(root.glob(f"{needle}_*.txt")):
        yield path, path.read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--windows-root", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.windows_root)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary = ["p2r_library_delta", "=================", ""]

    for needle in ("P2R_B2", "P2R_B3"):
        op_counter: Counter[str] = Counter()
        mask_counter: Counter[str] = Counter()
        seq_counter: Counter[str] = Counter()
        predecessor_counter: Counter[str] = Counter()
        successor_counter: Counter[str] = Counter()

        for path, text in iter_windows(root, needle):
            ops: list[str] = []
            lines = text.splitlines()
            hit_idx = None
            for idx, line in enumerate(lines):
                m = OP_RE.search(line)
                if not m:
                    continue
                op = m.group(1)
                ops.append(op)
                op_counter[op] += 1
                for imm in HEX_RE.findall(line):
                    if needle.replace("_", ".") in line or "R2P" in line:
                        mask_counter[imm] += 1
                if needle.replace("_", ".") in line:
                    hit_idx = len(ops) - 1
            if hit_idx is not None:
                start = max(0, hit_idx - 3)
                stop = min(len(ops), hit_idx + 4)
                seq_counter[" -> ".join(ops[start:stop])] += 1
                if hit_idx > 0:
                    predecessor_counter[ops[hit_idx - 1]] += 1
                if hit_idx + 1 < len(ops):
                    successor_counter[ops[hit_idx + 1]] += 1

        summary.append(f"{needle}:")
        summary.append("top_ops:")
        for op, count in op_counter.most_common(12):
            summary.append(f"- {op}: {count}")
        summary.append("top_masks:")
        for imm, count in mask_counter.most_common(8):
            summary.append(f"- {imm}: {count}")
        summary.append("top_predecessors:")
        for op, count in predecessor_counter.most_common(8):
            summary.append(f"- {op}: {count}")
        summary.append("top_successors:")
        for op, count in successor_counter.most_common(8):
            summary.append(f"- {op}: {count}")
        summary.append("top_sequences:")
        for seq, count in seq_counter.most_common(8):
            summary.append(f"- x{count}: {seq}")
        summary.append("")

    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
