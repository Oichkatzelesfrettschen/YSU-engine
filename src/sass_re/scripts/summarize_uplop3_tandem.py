#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import re
import sys


METRICS = [
    "smsp__cycles_elapsed.avg",
    "smsp__inst_executed.sum",
    "dram__throughput.avg.pct_of_peak_sustained_elapsed",
    "lts__t_sector_hit_rate.pct",
    "smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct",
    "smsp__warp_issue_stalled_wait_per_warp_active.pct",
]


def read_metric_map(path: pathlib.Path) -> dict[str, str]:
    if not path.exists():
        return {}
    lines = path.read_text(encoding="utf-8").splitlines()
    header_idx = None
    for i, line in enumerate(lines):
        if line.startswith('"ID","Process ID","Process Name"'):
            header_idx = i
            break
    if header_idx is None or header_idx + 2 >= len(lines):
        return {}
    rows = list(csv.reader(lines[header_idx:]))
    if len(rows) < 3:
        return {}
    header = rows[0]
    data = rows[-1]
    if len(data) < len(header):
        data += [""] * (len(header) - len(data))
    return {k: v for k, v in zip(header, data) if k and v}


def memcheck_ok(path: pathlib.Path) -> str:
    if not path.exists():
        return "missing"
    text = path.read_text(encoding="utf-8")
    if "ERROR SUMMARY: 0 errors" in text:
        return "clean"
    return "errors_or_unknown"


def fuzz_summary(path: pathlib.Path, label: str) -> tuple[int, int]:
    if not path.exists():
        return (0, 0)
    same = 0
    diff = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(f"- {label}:"):
            continue
        if "same_sum" in line and "same_out_prefix" in line:
            same += 1
        if "diff_sum" in line or "diff_out_prefix" in line:
            diff += 1
    return same, diff


def main() -> int:
    if len(sys.argv) < 3:
        raise SystemExit(f"usage: {sys.argv[0]} <run_dir> <label1> [label2 ...]")
    run_dir = pathlib.Path(sys.argv[1])
    labels = sys.argv[2:]
    lines = ["uplop3_tandem_summary", "=====================", ""]
    for label in labels:
        lines.append(f"{label}:")
        metric_map = read_metric_map(run_dir / f"{label}_ncu.csv")
        stall_map = read_metric_map(run_dir / f"{label}_ncu_stalls.csv")
        merged = metric_map | stall_map
        for metric in METRICS:
            if metric in merged:
                lines.append(f"- {metric} = {merged[metric]}")
        lines.append(f"- memcheck = {memcheck_ok(run_dir / f'{label}_memcheck.txt')}")
        same, diff = fuzz_summary(run_dir / "fuzz" / "summary.txt", label)
        lines.append(f"- fuzz_summary = same:{same} diff_mentions:{diff}")
        lines.append("")
    (run_dir / "summary_metrics.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
