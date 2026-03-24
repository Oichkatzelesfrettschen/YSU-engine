#!/usr/bin/env python3
"""
Compare local symbolic P2R probe windows against cuDNN-mined P2R.B* windows.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re


FUNC_RE = re.compile(r"Function : ([A-Za-z0-9_]+)")
OP_RE = re.compile(r"/\*[^*]+\*/\s+([A-Z][A-Z0-9_.]*)")

TARGETS = [
    "probe_p2r_b1_literal_cudnn_exact",
    "probe_p2r_b1_secondbank_halfword_exact",
    "probe_p2r_b1_samecarrier_late4_exact",
    "probe_p2r_b1_samecarrier_r7style_exact",
    "probe_p2r_b1_dualpack_transition_exact",
    "probe_p2r_b1_nibble_exact",
    "probe_p2r_b1_nibble_transition_exact",
    "probe_p2r_b1_regmask_transition_exact",
    "probe_p2r_b2_literal_cudnn_exact",
    "probe_p2r_b2_split_seed_exact",
    "probe_p2r_b2_nibble_exact",
    "probe_p2r_b2_nibble_transition_exact",
    "probe_p2r_b2_regmask_transition_exact",
    "probe_p2r_b2_tripack_prefix_exact",
    "probe_p2r_b3_literal_cudnn_exact",
    "probe_p2r_b3_split_seed_exact",
    "probe_p2r_b3_nibble_exact",
    "probe_p2r_b3_nibble_transition_exact",
    "probe_p2r_b3_regmask_transition_exact",
    "probe_p2r_b3_tripack_prefix_exact",
    "probe_p2r_b1_split_seed_exact",
]


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


def find_reference_windows(path: pathlib.Path) -> dict[str, set[str]]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    refs = {"P2R.B1": set(), "P2R.B2": set(), "P2R.B3": set()}
    for i, line in enumerate(lines):
        for tag in refs:
            if tag in line:
                window = lines[max(0, i - 10): min(len(lines), i + 11)]
                ops = set()
                for w in window:
                    m = OP_RE.search(w)
                    if m:
                        ops.add(m.group(1))
                refs[tag].update(ops)
    return refs


def jaccard(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def classify(name: str) -> str:
    if "_b1_" in name or name.endswith("b1_exact"):
        return "P2R.B1"
    if "_b2_" in name or name.endswith("b2_exact"):
        return "P2R.B2"
    if "_b3_" in name or name.endswith("b3_exact"):
        return "P2R.B3"
    return "P2R.B1"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("sass")
    parser.add_argument("reference")
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    sass = pathlib.Path(args.sass)
    reference = pathlib.Path(args.reference)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    funcs = parse_functions(sass)
    refs = find_reference_windows(reference)

    rows = []
    for name in TARGETS:
        ops = set(funcs.get(name, []))
        tag = classify(name)
        rows.append(
            {
                "function": name,
                "target": tag,
                "emitted_p2r_b": any(op.startswith(tag) for op in ops),
                "emitted_plain_p2r": "P2R" in ops,
                "isept_count": sum(op.startswith("ISETP") for op in ops),
                "sel_count": sum(op == "SEL" for op in ops),
                "lop3_count": sum(op == "LOP3.LUT" for op in ops),
                "prmt_count": sum(op == "PRMT" for op in ops),
                "jaccard_vs_ref": round(jaccard(ops, refs[tag]), 6),
                "ops": sorted(ops),
            }
        )

    (outdir / "scores.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    with (outdir / "summary.txt").open("w", encoding="utf-8") as handle:
        handle.write("p2r_symbolic_scores\n")
        handle.write("===================\n\n")
        handle.write(f"sass={sass}\n")
        handle.write(f"reference={reference}\n\n")
        for row in rows:
            handle.write(
                f"- {row['function']}: target={row['target']}, "
                f"plain_p2r={row['emitted_plain_p2r']}, "
                f"jaccard_vs_ref={row['jaccard_vs_ref']}, "
                f"ISETP={row['isept_count']}, SEL={row['sel_count']}, "
                f"LOP3={row['lop3_count']}, PRMT={row['prmt_count']}\n"
            )
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
