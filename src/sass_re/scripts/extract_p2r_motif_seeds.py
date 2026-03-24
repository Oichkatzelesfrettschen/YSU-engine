#!/usr/bin/env python3
"""
Extract exact B2/B3 motif seeds from mined cuDNN windows.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
from collections import Counter, defaultdict


OP_RE = re.compile(r"/\*[0-9a-f]+\*/\s+(?:@[!P0-9T]+\s+)?([A-Z0-9_.]+)")


def parse_window(path: pathlib.Path) -> tuple[list[str], int | None]:
    ops: list[str] = []
    hit_idx = None
    parts = path.stem.split("_")
    tag = f"{parts[0]}.{parts[1]}"
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = OP_RE.search(line)
        if not m:
            continue
        op = m.group(1)
        ops.append(op)
        if tag == "P2R.B2" and "P2R.B2" in line:
            hit_idx = len(ops) - 1
        if tag == "P2R.B3" and "P2R.B3" in line:
            hit_idx = len(ops) - 1
    return ops, hit_idx


def classify_seed(tag: str, window: list[str], hit_idx: int) -> dict[str, object]:
    preds = window[max(0, hit_idx - 3):hit_idx]
    succs = window[hit_idx + 1:hit_idx + 4]
    opset = set(window)
    return {
        "target": tag,
        "window": window,
        "predecessors": preds,
        "successors": succs,
        "has_r2p": "R2P" in opset,
        "has_bar_sync": any(op.startswith("BAR.SYNC") for op in opset),
        "has_uldc": any(op.startswith("ULDC") for op in opset),
        "has_lds64": "LDS.64" in opset,
        "has_ldgsts": any(op.startswith("LDGSTS") for op in opset),
        "has_lea": "LEA" in opset or "LEA.HI.X" in opset,
        "pred_kind": "ISETP.GE" if any(op.startswith("ISETP.GE") for op in preds) else (
            "ISETP.LT" if any(op.startswith("ISETP.LT") for op in preds) else "other"
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--windows-root", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.windows_root)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    seeds: list[dict[str, object]] = []
    class_counter: Counter[str] = Counter()
    target_counter: Counter[str] = Counter()
    pred_counter: defaultdict[str, Counter[str]] = defaultdict(Counter)

    for tag in ("P2R_B2", "P2R_B3"):
        for path in sorted(root.rglob(f"{tag}_*.txt")):
            ops, hit_idx = parse_window(path)
            if hit_idx is None:
                continue
            start = max(0, hit_idx - 3)
            stop = hit_idx + 4
            seed = classify_seed(tag.replace("_", "."), ops[start:stop], hit_idx - start)
            seed["source"] = str(path)
            seed["class"] = (
                f"{seed['target']}|pred={seed['pred_kind']}|"
                f"r2p={int(seed['has_r2p'])}|bar={int(seed['has_bar_sync'])}|"
                f"uldc={int(seed['has_uldc'])}|lds64={int(seed['has_lds64'])}|"
                f"ldgsts={int(seed['has_ldgsts'])}|lea={int(seed['has_lea'])}"
            )
            seeds.append(seed)
            class_counter[str(seed["class"])] += 1
            target_counter[str(seed["target"])] += 1
            for pred in seed["predecessors"]:  # type: ignore[index]
                pred_counter[str(seed["target"])][str(pred)] += 1

    ranked = sorted(seeds, key=lambda s: (class_counter[str(s["class"])], s["target"]), reverse=True)
    payload = {
        "windows_root": str(root),
        "count": len(ranked),
        "targets": target_counter,
        "top_classes": class_counter.most_common(16),
        "top_predicates": {k: v.most_common(8) for k, v in pred_counter.items()},
        "seeds": ranked,
    }
    (outdir / "seeds.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

    summary = ["p2r_motif_seeds", "===============", ""]
    summary.append(f"- windows_root: {root}")
    summary.append(f"- count: {len(ranked)}")
    summary.append("- top_classes:")
    for cls, count in class_counter.most_common(12):
        summary.append(f"  - x{count}: {cls}")
    summary.append("- top_predicates:")
    for target, items in pred_counter.items():
        summary.append(f"  - {target}:")
        for op, count in items.most_common(6):
            summary.append(f"    - {op}: {count}")
    summary.append("- strongest_examples:")
    for seed in ranked[:12]:
        summary.append(
            f"  - {seed['target']} from {pathlib.Path(str(seed['source'])).name}: "
            f"class={seed['class']}, window={' -> '.join(seed['window'])}"
        )
    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
