#!/usr/bin/env python3
"""
Build a semantic patch shortlist from local plain-P2R patchpoints and B2/B3 seeds.
"""

from __future__ import annotations

import argparse
import json
import pathlib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--patchpoints", required=True)
    parser.add_argument("--seeds", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    patchpoints = json.loads(pathlib.Path(args.patchpoints).read_text(encoding="utf-8"))
    seeds = json.loads(pathlib.Path(args.seeds).read_text(encoding="utf-8"))["seeds"]
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    b2_seed = next((s for s in seeds if s["target"] == "P2R.B2" and s["has_r2p"] and s["has_lea"]), None)
    b3_seed = next((s for s in seeds if s["target"] == "P2R.B3" and s["has_bar_sync"]), None)

    rows = []
    for row in patchpoints[:8]:
        target = "P2R.B3" if row["b3_jaccard"] >= row["b2_jaccard"] else "P2R.B2"
        chosen_seed = b3_seed if target == "P2R.B3" else b2_seed
        rows.append(
            {
                "sass": row["sass"],
                "function": row["function"],
                "recommended_target": target,
                "plain_p2r": row["plain_p2r"],
                "rationale": (
                    "best local overlap to B3 motif family" if target == "P2R.B3"
                    else "best local overlap to B2 motif family"
                ),
                "local_features": {
                    "has_uldc": row["has_uldc"],
                    "has_bar": row["has_bar"],
                    "has_lds": row["has_lds"],
                    "has_r2p": row["has_r2p"],
                    "has_prmt": row["has_prmt"],
                },
                "seed_class": chosen_seed["class"] if chosen_seed else None,
                "seed_window": chosen_seed["window"] if chosen_seed else None,
            }
        )

    (outdir / "shortlist.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    summary = ["p2r_cubin_semantic_patch", "========================", ""]
    for row in rows:
        summary.append(
            f"- {pathlib.Path(row['sass']).name}:{row['function']}: "
            f"target={row['recommended_target']}, plain_p2r={row['plain_p2r']}, "
            f"reason={row['rationale']}, seed_class={row['seed_class']}"
        )
    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
