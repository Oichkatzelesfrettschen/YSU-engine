#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import sys


BASE_METRICS = [
    "smsp__cycles_elapsed.avg",
    "smsp__inst_executed.sum",
    "dram__throughput.avg.pct_of_peak_sustained_elapsed",
    "lts__t_sector_hit_rate.pct",
    "sm__throughput.avg.pct_of_peak_sustained_elapsed",
    "launch__registers_per_thread",
    "launch__shared_mem_per_block_static",
]

STALL_METRICS = [
    "smsp__warp_issue_stalled_barrier_per_warp_active.pct",
    "smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct",
    "smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct",
    "smsp__warp_issue_stalled_membar_per_warp_active.pct",
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
    reader = csv.reader(lines[header_idx:])
    rows = list(reader)
    if len(rows) < 3:
        return {}
    header = rows[0]
    data = rows[-1]
    if len(data) < len(header):
        data = data + [""] * (len(header) - len(data))
    return {
        key: value for key, value in zip(header, data) if key and value
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <run_dir>")
    run_dir = pathlib.Path(sys.argv[1])
    labels = ["baseline", "occ4", "occ5", "occ2_occ4_occ5"]
    lines = ["uplop3_cutlass_predicate_ncu_summary", "==================================", ""]
    for label in labels:
        base = read_metric_map(run_dir / f"{label}_ncu.csv")
        stalls = read_metric_map(run_dir / f"{label}_ncu_stalls.csv")
        lines.append(f"{label}:")
        for metric in BASE_METRICS:
            if metric in base:
                lines.append(f"- {metric} = {base[metric]}")
        for metric in STALL_METRICS:
            if metric in stalls:
                lines.append(f"- {metric} = {stalls[metric]}")
        lines.append("")
    (run_dir / "summary_metrics.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
