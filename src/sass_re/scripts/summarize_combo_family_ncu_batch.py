#!/usr/bin/env python3
import csv
import pathlib
import statistics
import sys


PRIMARY_COLS = [
    "smsp__cycles_elapsed.avg",
    "smsp__inst_executed.sum",
    "dram__throughput.avg.pct_of_peak_sustained_elapsed",
    "lts__t_sector_hit_rate.pct",
    "sm__throughput.avg.pct_of_peak_sustained_elapsed",
    "launch__registers_per_thread",
    "launch__shared_mem_per_block_static",
]

STALL_COLS = [
    "smsp__warp_issue_stalled_barrier_per_warp_active.pct",
    "smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct",
    "smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct",
    "smsp__warp_issue_stalled_membar_per_warp_active.pct",
    "smsp__warp_issue_stalled_wait_per_warp_active.pct",
]


def load_rows(path: pathlib.Path):
    rows = []
    with path.open(newline="") as f:
        for line in f:
            if line.startswith('"ID"') or (line and line[0].isdigit()) or line.startswith('"'):
                rows.append(line)
    return rows


def mean_metrics(csv_path: pathlib.Path, kernel_name: str, cols):
    rdr = csv.DictReader(load_rows(csv_path))
    vals = {c: [] for c in cols}
    for row in rdr:
        if row.get("Kernel Name") != kernel_name:
            continue
        for c in cols:
            vals[c].append(float(row[c]))
    return {c: statistics.fmean(v) for c, v in vals.items()}


def main():
    if len(sys.argv) != 2:
        print("usage: summarize_combo_family_ncu_batch.py <run_dir>", file=sys.stderr)
        return 1

    run_dir = pathlib.Path(sys.argv[1])
    matrix_path = run_dir / "matrix.csv"
    summary_path = run_dir / "summary.txt"

    runs = {
        "small_safe_default": (
            run_dir / "small_safe_default",
            "probe_combo_warp_atomic_cache_profile_safe",
        ),
        "small_safe_dlcm_cg": (
            run_dir / "small_safe_dlcm_cg",
            "probe_combo_warp_atomic_cache_profile_safe",
        ),
        "small_depth_default": (
            run_dir / "small_depth_default",
            "probe_combo_warp_atomic_cache_profile_depth_safe",
        ),
        "small_depth_dlcm_cg": (
            run_dir / "small_depth_dlcm_cg",
            "probe_combo_warp_atomic_cache_profile_depth_safe",
        ),
        "sys_shallow_default": (
            run_dir / "sys_shallow_default",
            "probe_combo_blockred_warp_atomg64sys_ops_profile_safe",
        ),
        "sys_shallow_dlcm_cg": (
            run_dir / "sys_shallow_dlcm_cg",
            "probe_combo_blockred_warp_atomg64sys_ops_profile_safe",
        ),
        "sys_deep_default": (
            run_dir / "sys_deep_default",
            "probe_combo_blockred_warp_atomg64sys_ops_profile_depth_safe",
        ),
        "sys_store_default": (
            run_dir / "sys_store_default",
            "probe_combo_blockred_warp_atomg64sys_ops_store_profile_safe",
        ),
        "sys_store_dlcm_cg": (
            run_dir / "sys_store_dlcm_cg",
            "probe_combo_blockred_warp_atomg64sys_ops_store_profile_safe",
        ),
    }

    rows = []
    for label, (base, kernel) in runs.items():
        row = {"label": label}
        row.update(mean_metrics(base / "ncu.csv", kernel, PRIMARY_COLS))
        row.update(mean_metrics(base / "ncu_stalls.csv", kernel, STALL_COLS))
        rows.append(row)

    with matrix_path.open("w", newline="") as f:
        fieldnames = ["label"] + PRIMARY_COLS + STALL_COLS
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)

    idx = {r["label"]: r for r in rows}
    with summary_path.open("w") as f:
        f.write("combo_family_ncu_batch\n")
        f.write("======================\n\n")
        f.write("runs:\n")
        for label, (base, _) in runs.items():
            f.write(f"- {label}: {base}\n")
        f.write("\nkey findings:\n")
        f.write(
            "- small safe family stays dependency-depth / scoreboard driven, with "
            "barrier and membar effectively absent in both shallow and deep forms.\n"
        )
        f.write(
            f"- small shallow -> deep: inst "
            f"{idx['small_safe_default']['smsp__inst_executed.sum']:.0f} -> "
            f"{idx['small_depth_default']['smsp__inst_executed.sum']:.0f}, "
            f"short_scoreboard "
            f"{idx['small_safe_default']['smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct']:.2f}% -> "
            f"{idx['small_depth_default']['smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct']:.2f}%, "
            f"wait "
            f"{idx['small_safe_default']['smsp__warp_issue_stalled_wait_per_warp_active.pct']:.2f}% -> "
            f"{idx['small_depth_default']['smsp__warp_issue_stalled_wait_per_warp_active.pct']:.2f}%\n"
        )
        f.write(
            f"- 64-bit SYS shallow -> deep: inst "
            f"{idx['sys_shallow_default']['smsp__inst_executed.sum']:.0f} -> "
            f"{idx['sys_deep_default']['smsp__inst_executed.sum']:.0f}, "
            f"long_scoreboard "
            f"{idx['sys_shallow_default']['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}% -> "
            f"{idx['sys_deep_default']['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}%, "
            f"membar "
            f"{idx['sys_shallow_default']['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}% -> "
            f"{idx['sys_deep_default']['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}%\n"
        )
        f.write(
            f"- store-side SYS-safe: direct SYS load/store survives with "
            f"{idx['sys_store_default']['smsp__inst_executed.sum']:.0f} instructions, "
            f"{idx['sys_store_default']['launch__registers_per_thread']:.0f} regs, "
            f"long_scoreboard "
            f"{idx['sys_store_default']['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}%, "
            f"membar "
            f"{idx['sys_store_default']['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}%\n"
        )
        f.write(
            f"- `-dlcm=cg` on the store-side branch: L2 hit "
            f"{idx['sys_store_default']['lts__t_sector_hit_rate.pct']:.2f}% -> "
            f"{idx['sys_store_dlcm_cg']['lts__t_sector_hit_rate.pct']:.2f}%, "
            f"cycles "
            f"{idx['sys_store_default']['smsp__cycles_elapsed.avg']:.2f} -> "
            f"{idx['sys_store_dlcm_cg']['smsp__cycles_elapsed.avg']:.2f}\n"
        )

    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
