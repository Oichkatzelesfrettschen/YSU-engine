#!/usr/bin/env python3
"""
Normalize the P2R.B* symbolic frontier into a compact RCA summary.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
from collections import defaultdict


FUNC_RE = re.compile(r"Function : ([A-Za-z0-9_]+)")
OP_RE = re.compile(r"/\*[^*]+\*/\s+([A-Z][A-Z0-9_.]*)")


def parse_functions(path: pathlib.Path) -> dict[str, list[str]]:
    text = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    funcs: dict[str, list[str]] = {}
    current = None
    for line in text:
        m = FUNC_RE.search(line)
        if m:
            current = m.group(1)
            funcs[current] = []
            continue
        if current is None:
            continue
        op = OP_RE.search(line)
        if op:
            funcs[current].append(op.group(1))
    return funcs


def target_of(name: str) -> str:
    if "_b1_" in name:
        return "B1"
    if "_b2_" in name:
        return "B2"
    if "_b3_" in name:
        return "B3"
    return "generic"


def classify_probe(name: str) -> dict[str, str]:
    source_kind = "ISETP-heavy"
    if "plop3" in name:
        source_kind = "PLOP3-fed"

    carrier = "generic"
    if "samecarrier" in name:
        carrier = "same-carrier"
    elif "split_seed" in name:
        carrier = "split-seed"
    elif "regmask" in name:
        carrier = "regmask"
    elif "tripack" in name:
        carrier = "tripack-prefix"
    elif "dualpack" in name:
        carrier = "dualpack"
    elif "secondbank" in name:
        carrier = "second-bank"
    elif "nibble" in name:
        carrier = "nibble"
    elif "literal_cudnn" in name:
        carrier = "literal-cudnn"

    pack = "default"
    if "nibble" in name:
        pack = "0x0f"
    elif "samecarrier_r7style" in name or "split_seed" in name:
        pack = "0x7f"
    elif "tripack" in name:
        pack = "tripack-0x0f"
    elif "selpack" in name:
        pack = "selpack"

    prefix = "none"
    if "split_seed" in name:
        prefix = "0x80-split"
    elif "tripack" in name:
        prefix = "prior-byte-prefix"
    elif "secondbank" in name:
        prefix = "second-bank-halfword"

    return {
        "target": target_of(name),
        "source_kind": source_kind,
        "carrier_style": carrier,
        "pack_style": pack,
        "prefix_state": prefix,
    }


def summarize_scores(rows: list[dict]) -> dict[str, list[tuple[str, float]]]:
    groups: dict[str, list[tuple[str, float]]] = defaultdict(list)
    for row in rows:
        meta = classify_probe(row["function"])
        groups[f"target={meta['target']}"].append((row["function"], row["jaccard_vs_ref"]))
        groups[f"carrier={meta['carrier_style']}"].append((row["function"], row["jaccard_vs_ref"]))
        groups[f"pack={meta['pack_style']}"].append((row["function"], row["jaccard_vs_ref"]))
        groups[f"prefix={meta['prefix_state']}"].append((row["function"], row["jaccard_vs_ref"]))
        plain = "plain-p2r" if row["emitted_plain_p2r"] else "no-plain-p2r"
        groups[f"plain={plain}"].append((row["function"], row["jaccard_vs_ref"]))
        prmt = "prmt" if row["prmt_count"] else "no-prmt"
        groups[f"prmt={prmt}"].append((row["function"], row["jaccard_vs_ref"]))
    return groups


def aggregate_group(items: list[tuple[str, float]]) -> tuple[float, str, float]:
    avg = sum(score for _, score in items) / len(items)
    best_name, best_score = max(items, key=lambda x: x[1])
    return avg, best_name, best_score


def plop3_run_rows(run_sass: pathlib.Path) -> list[dict]:
    funcs = parse_functions(run_sass)
    rows = []
    for name, ops in funcs.items():
        if not name.startswith("probe_p2r_plop3_"):
            continue
        op_set = set(ops)
        rows.append(
            {
                "function": name,
                "ops": sorted(op_set),
                "has_plain_p2r": "P2R" in op_set,
                "has_byte_p2r": any(op.startswith("P2R.B") for op in op_set),
                "has_plop3": "PLOP3.LUT" in op_set,
                "has_predicate_lop3": any(op == "LOP3.LUT" for op in op_set),
                "has_prmt": "PRMT" in op_set,
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scores-json", required=True)
    parser.add_argument("--plop3-sass", nargs="*", default=[])
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = json.loads(pathlib.Path(args.scores_json).read_text(encoding="utf-8"))
    grouped = summarize_scores(rows)

    plop3_rows = []
    for path in args.plop3_sass:
        plop3_rows.extend(plop3_run_rows(pathlib.Path(path)))

    lines = []
    lines.append("p2r_frontier_analysis")
    lines.append("=====================")
    lines.append("")
    lines.append("What are we actually looking for?")
    lines.append("- Direct local optimized SASS on sm_89 that emits P2R.B1, P2R.B2, or P2R.B3.")
    lines.append("- Not library-mined evidence, not plain P2R, and not debug-only neighbors.")
    lines.append("")
    lines.append("Normalized score trends from the symbolic matrix:")
    for key in sorted(grouped):
        avg, best_name, best_score = aggregate_group(grouped[key])
        lines.append(
            f"- {key}: avg_jaccard={avg:.6f}, best={best_name}, best_jaccard={best_score:.6f}"
        )
    lines.append("")
    best_overall = sorted(rows, key=lambda r: r["jaccard_vs_ref"], reverse=True)[:8]
    lines.append("Top local approximations:")
    for row in best_overall:
        meta = classify_probe(row["function"])
        lines.append(
            "- "
            f"{row['function']}: target={meta['target']}, "
            f"source={meta['source_kind']}, carrier={meta['carrier_style']}, "
            f"pack={meta['pack_style']}, prefix={meta['prefix_state']}, "
            f"plain_p2r={row['emitted_plain_p2r']}, "
            f"jaccard={row['jaccard_vs_ref']}"
        )
    lines.append("")
    lines.append("PLOP3-fed follow-up observations:")
    if plop3_rows:
        for row in plop3_rows:
            lines.append(
                "- "
                f"{row['function']}: has_plop3={row['has_plop3']}, "
                f"predicate_lop3={row['has_predicate_lop3']}, "
                f"plain_p2r={row['has_plain_p2r']}, "
                f"byte_p2r={row['has_byte_p2r']}, "
                f"prmt={row['has_prmt']}"
            )
    else:
        lines.append("- no plop3 rows supplied")
    lines.append("")
    lines.append("Interpretation:")
    lines.append("- Carrier-lifetime and prefix-state axes are strip-mined.")
    lines.append("- Predicate-source kind is real, but insufficient by itself.")
    lines.append("- The best B1 approximations outperform B2/B3 approximations.")
    lines.append("- B3-shaped paths are the most PRMT-prone, which suggests ptxas prefers byte permutation glue there.")
    lines.append("- The frontier is no longer neighborhood discovery; it is form-selection control.")
    lines.append("")
    lines.append("Novel next methods:")
    lines.append("- PTX-level search: generate NVVM/PTX boolean banks and let ptxas re-lower them outside CUDA C++ source patterns.")
    lines.append("- Toolchain sweep: rerun the best B1/B2/B3 probes across multiple nvcc/ptxas versions to test whether P2R.B* is version-gated.")
    lines.append("- Frontend sweep: emit equivalent kernels via clang CUDA, Triton, or MLIR NVVM to perturb pre-ptxas IR shape.")
    lines.append("- Binary delta mining: diff more cuDNN/cuBLAS/TensorRT pockets around P2R.B* and mine immediate predecessor opcode windows, not just set overlap.")
    lines.append("- CEGIS/source mutator: use the auto-explorer to mutate only the surviving axes and reject already-exhausted ones.")
    lines.append("- Cubin surgery: if the goal becomes semantic validation rather than source reproducibility, patch plain P2R sites into P2R.B* and validate behavior.")
    lines.append("")

    summary = "\n".join(lines) + "\n"
    (outdir / "summary.txt").write_text(summary, encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
