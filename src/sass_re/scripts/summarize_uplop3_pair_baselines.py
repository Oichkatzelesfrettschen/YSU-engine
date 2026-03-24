#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys


FUZZ_RE = re.compile(r"^- ([^:]+): (.+)$")


def count_fuzz(summary: pathlib.Path, label: str) -> tuple[int, int]:
    if not summary.exists():
        return (0, 0)
    same = 0
    diff = 0
    for line in summary.read_text(encoding="utf-8").splitlines():
        match = FUZZ_RE.match(line)
        if not match or match.group(1) != label:
            continue
        payload = match.group(2)
        if "same_sum" in payload and "same_out_prefix" in payload:
            same += 1
        if "diff_sum" in payload or "diff_out_prefix" in payload:
            diff += 1
    return same, diff


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <uniform_run_dir> <cutlass_run_dir>")
    uniform_dir = pathlib.Path(sys.argv[1])
    cutlass_dir = pathlib.Path(sys.argv[2])
    lines = ["uplop3_pair_baseline_summary", "===========================", ""]

    uniform_cases = ["baseline", "occ1", "occ1_occ5", "occ1_occ2_occ5"]
    lines.append("uniform_pair_baseline:")
    for label in uniform_cases:
        same, diff = count_fuzz(uniform_dir / "fuzz" / "summary.txt", label)
        lines.append(f"- {label}: same:{same} diff_mentions:{diff}")
    lines.append("")

    cutlass_cases = ["baseline", "occ4", "occ4_occ5", "occ2_occ4_occ5"]
    lines.append("cutlass_pair_baseline:")
    for label in cutlass_cases:
        same, diff = count_fuzz(cutlass_dir / "fuzz" / "summary.txt", label)
        lines.append(f"- {label}: same:{same} diff_mentions:{diff}")
    lines.append("")

    out_path = cutlass_dir.parent / f"{uniform_dir.name}__{cutlass_dir.name}__pair_summary.txt"
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
