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


def _load_rows(path: pathlib.Path):
    rows = []
    with path.open(newline="") as f:
        for line in f:
            if line.startswith('"ID"') or (line and line[0].isdigit()) or line.startswith('"'):
                rows.append(line)
    return rows


def _mean_metrics(csv_path: pathlib.Path, kernel_name: str, cols):
    rows = _load_rows(csv_path)
    rdr = csv.DictReader(rows)
    vals = {c: [] for c in cols}
    for row in rdr:
        if row.get("Kernel Name") != kernel_name:
            continue
        for c in cols:
            vals[c].append(float(row[c]))
    return {c: statistics.fmean(v) for c, v in vals.items()}


def main():
    if len(sys.argv) != 2:
        print("usage: summarize_combo_sys_runtime_matrix.py <run_dir>", file=sys.stderr)
        return 1

    run_dir = pathlib.Path(sys.argv[1])
    run_dir.mkdir(parents=True, exist_ok=True)

    runs = {
        "shallow_default": (
            pathlib.Path("src/sass_re/results/runs/combo_blockred_warp_atomg64sys_ops_profile_safe_tranche_20260322_002817"),
            "probe_combo_blockred_warp_atomg64sys_ops_profile_safe",
        ),
        "shallow_dlcm_cg": (
            pathlib.Path("src/sass_re/results/runs/combo_blockred_warp_atomg64sys_ops_profile_safe_tranche_dlcm_cg_20260322_003600"),
            "probe_combo_blockred_warp_atomg64sys_ops_profile_safe",
        ),
        "deep_default": (
            pathlib.Path("src/sass_re/results/runs/combo_blockred_warp_atomg64sys_ops_profile_depth_safe_tranche_20260322_005633"),
            "probe_combo_blockred_warp_atomg64sys_ops_profile_depth_safe",
        ),
        "store_default": (
            pathlib.Path("src/sass_re/results/runs/combo_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_20260322_005938"),
            "probe_combo_blockred_warp_atomg64sys_ops_store_profile_safe",
        ),
        "store_dlcm_cg": (
            pathlib.Path("src/sass_re/results/runs/combo_blockred_warp_atomg64sys_ops_store_profile_safe_tranche_dlcm_cg_20260322_010500"),
            "probe_combo_blockred_warp_atomg64sys_ops_store_profile_safe",
        ),
    }

    matrix_path = run_dir / "matrix.csv"
    summary_path = run_dir / "summary.txt"

    with matrix_path.open("w", newline="") as f:
        fieldnames = ["label"] + PRIMARY_COLS + STALL_COLS
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        rows = []
        for label, (base, kernel) in runs.items():
            primary = _mean_metrics(base / "ncu.csv", kernel, PRIMARY_COLS)
            stalls = _mean_metrics(base / "ncu_stalls.csv", kernel, STALL_COLS)
            row = {"label": label}
            row.update(primary)
            row.update(stalls)
            w.writerow(row)
            rows.append(row)

    shallow = rows[0]
    deep = rows[2]
    store = rows[3]
    store_cg = rows[4]

    with summary_path.open("w") as f:
        f.write("combo_sys_runtime_matrix\n")
        f.write("========================\n\n")
        f.write("runs:\n")
        for label, (base, _) in runs.items():
            f.write(f"- {label}: {base}\n")
        f.write("\nkey findings:\n")
        f.write(
            f"- shallow -> deep: inst {shallow['smsp__inst_executed.sum']:.0f} -> "
            f"{deep['smsp__inst_executed.sum']:.0f}, regs {shallow['launch__registers_per_thread']:.0f} -> "
            f"{deep['launch__registers_per_thread']:.0f}, shared "
            f"{shallow['launch__shared_mem_per_block_static']:.0f} -> "
            f"{deep['launch__shared_mem_per_block_static']:.0f}\n"
        )
        f.write(
            f"- shallow -> deep stall shift: long_scoreboard "
            f"{shallow['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}% -> "
            f"{deep['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}%, "
            f"membar {shallow['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}% -> "
            f"{deep['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}%, "
            f"short_scoreboard {shallow['smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct']:.2f}% -> "
            f"{deep['smsp__warp_issue_stalled_short_scoreboard_per_warp_active.pct']:.2f}%, "
            f"wait {shallow['smsp__warp_issue_stalled_wait_per_warp_active.pct']:.2f}% -> "
            f"{deep['smsp__warp_issue_stalled_wait_per_warp_active.pct']:.2f}%\n"
        )
        f.write(
            f"- store_default: long_scoreboard "
            f"{store['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}%, "
            f"membar {store['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}%, "
            f"inst {store['smsp__inst_executed.sum']:.0f}, regs {store['launch__registers_per_thread']:.0f}\n"
        )
        f.write(
            f"- store_default -> store_dlcm_cg: cycles "
            f"{store['smsp__cycles_elapsed.avg']:.2f} -> {store_cg['smsp__cycles_elapsed.avg']:.2f}, "
            f"L2 hit {store['lts__t_sector_hit_rate.pct']:.2f}% -> "
            f"{store_cg['lts__t_sector_hit_rate.pct']:.2f}%, "
            f"long_scoreboard {store['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}% -> "
            f"{store_cg['smsp__warp_issue_stalled_long_scoreboard_per_warp_active.pct']:.2f}%, "
            f"membar {store['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}% -> "
            f"{store_cg['smsp__warp_issue_stalled_membar_per_warp_active.pct']:.2f}%\n"
        )

    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
