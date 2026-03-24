#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
TABLES = ROOT / "tables"
RESULTS = ROOT / "results/runs"
OUT = ROOT / "processed/monograph_20260323"

RUNTIME_CLASS = RESULTS / "uplop3_runtime_class_matrix_20260323_024000/summary.txt"
PAIR_SUMMARY = RESULTS / "uplop3_uniform_pair_baseline_20260323_094600__uplop3_cutlass_pair_baseline_20260323_094718__pair_summary.txt"


def write_csv(path: pathlib.Path, header: list[str], rows: list[list[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


def clean_numeric(text: str) -> str:
    return text.replace("**", "").replace("`", "")


def generate_inventory_numeric() -> pathlib.Path:
    src = TABLES / "table_a1_sm89_inventory_summary.csv"
    rows: list[list[object]] = []
    with src.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            metric = row["Metric"]
            value = clean_numeric(row["Value"])
            first_num = re.search(r"\d[\d,]*", value)
            numeric = first_num.group(0).replace(",", "") if first_num else ""
            rows.append([metric, value, numeric])
    out = OUT / "inventory_numeric.csv"
    write_csv(out, ["metric", "label_value", "numeric_value"], rows)
    return out


def generate_inventory_plot() -> pathlib.Path:
    rows = [
        ["canonical_frontier", 379],
        ["discovery_lane", 382],
        ["catalog_rows", 470],
    ]
    out = OUT / "inventory_plot.csv"
    write_csv(out, ["metric_key", "count"], rows)
    return out


def generate_p2r_status_numeric() -> pathlib.Path:
    src = TABLES / "table_a2_p2r_frontier_status.csv"
    score_map = {
        "not reproduced": 0,
        "reproduced": 1,
        "no direct P2R.B* unlock": 0,
        "materialized and runnable": 2,
        "source/IR form-selection problem, not opcode-existence problem": 1,
    }
    rows: list[list[object]] = []
    with src.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            result = row["Current result"]
            rows.append([row["Axis"], result, score_map.get(result, "")])
    out = OUT / "p2r_frontier_numeric.csv"
    write_csv(out, ["axis", "status", "score"], rows)
    return out


def generate_p2r_status_plot() -> pathlib.Path:
    rows = [
        ["source_ir_bstar", 0],
        ["plain_p2r_0x7f", 1],
        ["plain_p2r_0x0f", 1],
        ["frontend_sweeps", 0],
        ["cubin_bstar", 2],
        ["interpretation", 1],
    ]
    out = OUT / "p2r_frontier_plot.csv"
    write_csv(out, ["axis_key", "score"], rows)
    return out


def generate_runtime_class_counts() -> pathlib.Path:
    inert = 0
    stable = 0
    context_rows: list[list[object]] = []
    current = ""
    for line in RUNTIME_CLASS.read_text(encoding="utf-8").splitlines():
        if line.startswith("context="):
            current = line.split("=", 1)[1].strip()
        elif line.startswith("- "):
            name, rest = line[2:].split(":", 1)
            if "stable_but_different" in rest:
                stable += 1
                cls = "stable_but_different"
            else:
                inert += 1
                cls = "inert"
            context_rows.append([current, name.strip(), cls])
    out_counts = OUT / "uplop3_runtime_class_counts.csv"
    write_csv(
        out_counts,
        ["class", "count"],
        [["inert", inert], ["stable_but_different", stable]],
    )
    out_sites = OUT / "uplop3_runtime_sites.csv"
    write_csv(out_sites, ["context", "site", "class"], context_rows)
    return out_counts


def generate_runtime_class_plot() -> pathlib.Path:
    out = OUT / "uplop3_runtime_class_plot.csv"
    write_csv(out, ["class_key", "count"], [["inert", 12], ["stablediff", 3]])
    return out


def generate_live_site_numeric() -> pathlib.Path:
    src = TABLES / "table_a4_live_uplop3_site_ranking.csv"
    rows: list[list[object]] = []
    with src.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            j = float(row["Best jaccard"])
            rows.append([row["Rank"], row["Site"], row["Current role"], row["Best jaccard"], f"{1.0-j:.6f}"])
    out = OUT / "uplop3_live_site_numeric.csv"
    write_csv(out, ["rank", "site", "role", "best_jaccard", "distance_to_1"], rows)
    return out


def generate_live_site_plot() -> pathlib.Path:
    rows = [
        ["u1", 0.375000],
        ["c5", 0.375000],
        ["u2", 0.300000],
        ["c4", 0.333333],
        ["u5", 0.300000],
        ["co1", 0.300000],
    ]
    out = OUT / "uplop3_live_site_plot.csv"
    write_csv(out, ["site_key", "best_jaccard"], rows)
    return out


def generate_pair_baseline_numeric() -> pathlib.Path:
    rows: list[list[object]] = []
    current_family = ""
    rx = re.compile(r"^- ([^:]+): same:(\d+) diff_mentions:(\d+)")
    for line in PAIR_SUMMARY.read_text(encoding="utf-8").splitlines():
        if line.endswith("_pair_baseline:"):
            current_family = line[:-1]
            continue
        match = rx.match(line)
        if not match:
            continue
        same = int(match.group(2))
        diff = int(match.group(3))
        total = same + diff
        diff_ratio = diff / total if total else 0.0
        rows.append([current_family, match.group(1), same, diff, total, f"{diff_ratio:.6f}"])
    out = OUT / "uplop3_pair_baseline_numeric.csv"
    write_csv(out, ["family", "variant", "same", "diff", "total", "diff_ratio"], rows)
    return out


def generate_pair_baseline_plot() -> pathlib.Path:
    rows = [
        ["u_occ1", 0.708333],
        ["u_occ1_occ5", 0.708333],
        ["u_occ1_occ2_occ5", 0.458333],
        ["c_occ4", 1.000000],
        ["c_occ4_occ5", 0.666667],
        ["c_occ2_occ4_occ5", 0.625000],
    ]
    out = OUT / "uplop3_pair_baseline_plot.csv"
    write_csv(out, ["variant_key", "diff_ratio"], rows)
    return out


def generate_tool_effectiveness_numeric() -> pathlib.Path:
    src = TABLES / "table_a5_tool_effectiveness_matrix.csv"
    semantic_score = {
        "primary semantic discriminator": 3,
        "safety gate": 1,
        "perf sanity check": 1,
        "trace sidecar": 1,
    }
    rows: list[list[object]] = []
    with src.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            role = row["Current role"]
            rows.append([row["Tool"], role, semantic_score.get(role, 0)])
    out = OUT / "tool_effectiveness_numeric.csv"
    write_csv(out, ["tool", "role", "semantic_priority"], rows)
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    outputs = [
        generate_inventory_numeric(),
        generate_inventory_plot(),
        generate_p2r_status_numeric(),
        generate_p2r_status_plot(),
        generate_runtime_class_counts(),
        generate_runtime_class_plot(),
        generate_live_site_numeric(),
        generate_live_site_plot(),
        generate_pair_baseline_numeric(),
        generate_pair_baseline_plot(),
        generate_tool_effectiveness_numeric(),
    ]
    print("generated_monograph_assets")
    for path in outputs:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
