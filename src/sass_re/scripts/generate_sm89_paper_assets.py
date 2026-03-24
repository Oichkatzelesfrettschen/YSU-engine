#!/usr/bin/env python3
from __future__ import annotations

import csv
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]
RESULTS = ROOT / "RESULTS.md"
RUNTIME_CLASS = ROOT / "results/runs/uplop3_runtime_class_matrix_20260323_024000/summary.txt"
RANKINGS = ROOT / "results/runs/live_uplop3_occurrence_rankings_20260323_090200/summary.txt"
PAIR_SUMMARY = ROOT / "results/runs/uplop3_uniform_pair_baseline_20260323_094600__uplop3_cutlass_pair_baseline_20260323_094718__pair_summary.txt"
FIGURES = ROOT / "figures"
TABLES = ROOT / "tables"


def extract_inventory() -> list[tuple[str, str]]:
    text = RESULTS.read_text(encoding="utf-8")
    rows = []
    capture = False
    for line in text.splitlines():
        if line.strip() == "## Definitive Summary (2026-03-20)":
            capture = True
            continue
        if capture and line.startswith("### "):
            break
        if capture and line.startswith("| ") and not line.startswith("| Metric |"):
            parts = [p.strip() for p in line.strip().strip("|").split("|")]
            if len(parts) >= 2:
                rows.append((parts[0], parts[1]))
    return rows


def write_csv(path: pathlib.Path, header: list[str], rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


def write_inventory_csv() -> pathlib.Path:
    rows = [[metric, value] for metric, value in extract_inventory()]
    out = TABLES / "table_a1_sm89_inventory_summary.csv"
    write_csv(out, ["Metric", "Value"], rows)
    return out


def write_p2r_csv() -> pathlib.Path:
    rows = [
        ["Direct local source/IR emission of P2R.B1/B2/B3", "not reproduced"],
        ["Local plain P2R 0x7f", "reproduced"],
        ["Local plain P2R 0x0f", "reproduced"],
        ["PTX/clang/Triton/simple ptxas sweep", "no direct P2R.B* unlock"],
        ["Cubin-side local P2R.B1/B2/B3", "materialized and runnable"],
        ["Best current interpretation", "source/IR form-selection problem, not opcode-existence problem"],
    ]
    out = TABLES / "table_a2_p2r_frontier_status.csv"
    write_csv(out, ["Axis", "Current result"], rows)
    return out


def write_uplop3_boundary_csv() -> pathlib.Path:
    rows = [
        ["ULOP3 -> UPLOP3", "structurally invalid"],
        ["PLOP3 -> UPLOP3", "structurally valid"],
        ["Local runtime classes", "inert and stable-but-different"],
        ["Direct local source/IR emission of UPLOP3.LUT", "not reproduced"],
    ]
    out = TABLES / "table_a3_uplop3_structural_boundary.csv"
    write_csv(out, ["Patch path / class", "Current result"], rows)
    return out


def parse_runtime_classes() -> tuple[list[str], list[str]]:
    inert: list[str] = []
    live: list[str] = []
    current = ""
    for line in RUNTIME_CLASS.read_text(encoding="utf-8").splitlines():
        if line.startswith("context="):
            current = line.split("=", 1)[1].strip()
        elif line.startswith("- "):
            name, rest = line[2:].split(":", 1)
            label = f"{current}/{name.strip()}"
            if "stable_but_different" in rest:
                live.append(label)
            elif "inert" in rest:
                inert.append(label)
    return inert, live


def parse_rankings() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    current = None
    for line in RANKINGS.read_text(encoding="utf-8").splitlines():
        if line.startswith("context="):
            current = line.split("=", 1)[1].strip()
        elif line.startswith("- best_jaccard=") and current:
            rows.append((current, line.split("=", 1)[1].strip()))
    return rows


def write_live_site_csv() -> pathlib.Path:
    role_map = {
        "uniform_occ1": "anchor",
        "cutlass_occ5": "anchor",
        "uniform_occ2": "secondary anchor",
        "cutlass_occ4": "amplifier",
        "uniform_occ5": "sensitizer",
        "cooperative_occ1": "lower-priority live site",
    }
    ranking_rows = parse_rankings()
    order = ["uniform_occ1", "cutlass_occ5", "uniform_occ2", "cutlass_occ4", "uniform_occ5", "cooperative_occ1"]
    lookup = {k: v for k, v in ranking_rows}
    rows = [[str(i + 1), site, role_map[site], lookup.get(site, "")] for i, site in enumerate(order)]
    out = TABLES / "table_a4_live_uplop3_site_ranking.csv"
    write_csv(out, ["Rank", "Site", "Current role", "Best jaccard"], rows)
    return out


def write_tool_csv() -> pathlib.Path:
    rows = [
        ["Differential fuzzing", "primary semantic discriminator", "separates anchors, sensitizers, amplifiers, and broadeners", "not a safety tool"],
        ["compute-sanitizer", "safety gate", "shows live cubins are not merely obvious invalid memory behavior", "perturbs aggregate sums"],
        ["ncu", "perf sanity check", "helps rule out hidden perf-regime shifts", "weak semantic discriminator"],
        ["nsys", "trace sidecar", "preserves timelines and host/driver context for later analysis", "lower immediate yield than fuzzing/sanitizer"],
    ]
    out = TABLES / "table_a5_tool_effectiveness_matrix.csv"
    write_csv(out, ["Tool", "Current role", "Why it matters", "Caveat"], rows)
    return out


def parse_pair_summary() -> dict[str, tuple[int, int]]:
    pairs: dict[str, tuple[int, int]] = {}
    current_family = ""
    rx = re.compile(r"^- ([^:]+): same:(\d+) diff_mentions:(\d+)")
    for line in PAIR_SUMMARY.read_text(encoding="utf-8").splitlines():
        if line.endswith("_pair_baseline:"):
            current_family = line[:-1]
        else:
            m = rx.match(line)
            if m:
                pairs[f"{current_family}/{m.group(1)}"] = (int(m.group(2)), int(m.group(3)))
    return pairs


def write_runtime_class_svg() -> pathlib.Path:
    inert, live = parse_runtime_classes()
    pairs = parse_pair_summary()
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1260" height="840" viewBox="0 0 1260 840">
  <rect width="1260" height="840" fill="#ffffff"/>
  <text x="40" y="48" font-family="monospace" font-size="28" fill="#111111">Figure A2. UPLOP3 runtime class map</text>
  <text x="40" y="78" font-family="monospace" font-size="16" fill="#333333">Generated from runtime-class, live-site ranking, and pair-baseline summary artifacts.</text>

  <rect x="40" y="110" width="370" height="680" rx="10" fill="#f4f7fb" stroke="#8aa1b8" stroke-width="2"/>
  <text x="60" y="145" font-family="monospace" font-size="22" fill="#18324a">Runtime classes</text>
  <text x="60" y="176" font-family="monospace" font-size="16" fill="#1f5a1d">Inert sites: {len(inert)}</text>
  <text x="60" y="205" font-family="monospace" font-size="16" fill="#734600">Stable-but-different sites: {len(live)}</text>
  <text x="60" y="240" font-family="monospace" font-size="16" fill="#163216">Examples (inert):</text>
  <text x="80" y="268" font-family="monospace" font-size="14" fill="#163216">uniform_loop/uplop3_08</text>
  <text x="80" y="290" font-family="monospace" font-size="14" fill="#163216">uniform_loop/uplop3_80</text>
  <text x="80" y="312" font-family="monospace" font-size="14" fill="#163216">sliding_window_pt/uplop3_08</text>
  <text x="80" y="334" font-family="monospace" font-size="14" fill="#163216">tensor_ldsm/uplop3_80</text>
  <text x="60" y="380" font-family="monospace" font-size="16" fill="#4d3000">Examples (stable-but-different):</text>
  <text x="80" y="408" font-family="monospace" font-size="14" fill="#4d3000">cooperative_launch/uplop3_08</text>
  <text x="80" y="430" font-family="monospace" font-size="14" fill="#4d3000">uniform_predicates/uplop3_80</text>
  <text x="80" y="452" font-family="monospace" font-size="14" fill="#4d3000">uniform_predicates/uplop3_fe</text>
  <text x="60" y="500" font-family="monospace" font-size="16" fill="#18324a">Pair-baseline summary:</text>
  <text x="80" y="528" font-family="monospace" font-size="14" fill="#18324a">uniform occ1: same {pairs.get('uniform_pair_baseline/occ1', (0,0))[0]}, diff {pairs.get('uniform_pair_baseline/occ1', (0,0))[1]}</text>
  <text x="80" y="550" font-family="monospace" font-size="14" fill="#18324a">uniform occ1_occ2_occ5: same {pairs.get('uniform_pair_baseline/occ1_occ2_occ5', (0,0))[0]}, diff {pairs.get('uniform_pair_baseline/occ1_occ2_occ5', (0,0))[1]}</text>
  <text x="80" y="572" font-family="monospace" font-size="14" fill="#18324a">cutlass occ4: same {pairs.get('cutlass_pair_baseline/occ4', (0,0))[0]}, diff {pairs.get('cutlass_pair_baseline/occ4', (0,0))[1]}</text>
  <text x="80" y="594" font-family="monospace" font-size="14" fill="#18324a">cutlass occ2_occ4_occ5: same {pairs.get('cutlass_pair_baseline/occ2_occ4_occ5', (0,0))[0]}, diff {pairs.get('cutlass_pair_baseline/occ2_occ4_occ5', (0,0))[1]}</text>

  <rect x="450" y="110" width="340" height="680" rx="10" fill="#f8f4fb" stroke="#9d84b7" stroke-width="2"/>
  <text x="470" y="145" font-family="monospace" font-size="22" fill="#3f2558">Live-site hierarchy</text>
  <text x="470" y="185" font-family="monospace" font-size="18" fill="#631515">1. uniform_occ1 (jaccard 0.375)</text>
  <text x="470" y="220" font-family="monospace" font-size="18" fill="#6f3a00">2. cutlass_occ5 (jaccard 0.375)</text>
  <text x="470" y="255" font-family="monospace" font-size="18" fill="#6a5600">3. uniform_occ2 (jaccard 0.300)</text>
  <text x="470" y="290" font-family="monospace" font-size="18" fill="#173d93">4. cutlass_occ4 (jaccard 0.333333)</text>
  <text x="470" y="325" font-family="monospace" font-size="18" fill="#145472">5. uniform_occ5 (jaccard 0.300)</text>
  <text x="470" y="360" font-family="monospace" font-size="18" fill="#444444">6. cooperative_occ1 (jaccard 0.300)</text>
  <text x="470" y="420" font-family="monospace" font-size="16" fill="#3f2558">Current roles:</text>
  <text x="490" y="448" font-family="monospace" font-size="14" fill="#3f2558">uniform_occ1, cutlass_occ5 -> anchors</text>
  <text x="490" y="470" font-family="monospace" font-size="14" fill="#3f2558">uniform_occ2 -> secondary anchor</text>
  <text x="490" y="492" font-family="monospace" font-size="14" fill="#3f2558">cutlass_occ4 -> amplifier</text>
  <text x="490" y="514" font-family="monospace" font-size="14" fill="#3f2558">uniform_occ5 -> sensitizer</text>

  <rect x="830" y="110" width="390" height="680" rx="10" fill="#fbf7f3" stroke="#b59c86" stroke-width="2"/>
  <text x="850" y="145" font-family="monospace" font-size="22" fill="#5a4330">Causal interpretation</text>
  <text x="850" y="190" font-family="monospace" font-size="16" fill="#5a4330">Uniform pair baseline: occ2_occ5</text>
  <text x="870" y="220" font-family="monospace" font-size="14" fill="#5a4330">occ1 is the main extra widener</text>
  <text x="870" y="242" font-family="monospace" font-size="14" fill="#5a4330">triple partially re-stabilizes the pair</text>
  <text x="850" y="292" font-family="monospace" font-size="16" fill="#5a4330">CUTLASS pair baseline: occ2_occ5</text>
  <text x="870" y="322" font-family="monospace" font-size="14" fill="#5a4330">occ4 is the main visible widener</text>
  <text x="870" y="344" font-family="monospace" font-size="14" fill="#5a4330">richer combos often preserve prefix</text>
  <text x="870" y="366" font-family="monospace" font-size="14" fill="#5a4330">but perturb aggregate sums</text>
  <text x="850" y="430" font-family="monospace" font-size="16" fill="#5a4330">Method roles</text>
  <text x="870" y="458" font-family="monospace" font-size="14" fill="#5a4330">differential fuzzing -> semantic ranking</text>
  <text x="870" y="480" font-family="monospace" font-size="14" fill="#5a4330">compute-sanitizer -> safety gate</text>
  <text x="870" y="502" font-family="monospace" font-size="14" fill="#5a4330">ncu -> perf sanity check</text>
  <text x="870" y="524" font-family="monospace" font-size="14" fill="#5a4330">nsys -> trace sidecar</text>
  <text x="40" y="820" font-family="monospace" font-size="14" fill="#333333">Generated from repo artifacts by scripts/generate_sm89_paper_assets.py</text>
</svg>
"""
    out = FIGURES / "uplop3_runtime_class_map.generated.svg"
    FIGURES.mkdir(parents=True, exist_ok=True)
    out.write_text(svg, encoding="utf-8")
    return out


def main() -> int:
    inv = write_inventory_csv()
    p2r = write_p2r_csv()
    upl = write_uplop3_boundary_csv()
    live = write_live_site_csv()
    tool = write_tool_csv()
    fig = write_runtime_class_svg()
    print("generated_sm89_paper_assets")
    for path in [inv, p2r, upl, live, tool, fig]:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
