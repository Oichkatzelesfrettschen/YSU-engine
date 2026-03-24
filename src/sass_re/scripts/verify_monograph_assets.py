#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MONOGRAPH_MD = ROOT / "MONOGRAPH_SM89_SYNTHESIS.md"
MONOGRAPH_TEX = ROOT / "tex/sm89_monograph.tex"
PROCESSED = ROOT / "processed/monograph_20260323"

REQUIRED_FILES = [
    MONOGRAPH_MD,
    MONOGRAPH_TEX,
    PROCESSED / "inventory_numeric.csv",
    PROCESSED / "p2r_frontier_numeric.csv",
    PROCESSED / "uplop3_runtime_class_counts.csv",
    PROCESSED / "uplop3_runtime_sites.csv",
    PROCESSED / "uplop3_live_site_numeric.csv",
    PROCESSED / "uplop3_pair_baseline_numeric.csv",
    PROCESSED / "tool_effectiveness_numeric.csv",
]

REQUIRED_HEADINGS = [
    "# SM89 Frontier Monograph Synthesis",
    "## 1. Problem Statement",
    "## 4. The P2R Frontier",
    "## 5. The UPLOP3 Frontier",
    "## 8. Open Gaps And Next Falsifiable Experiments",
]


def main() -> int:
    errors: list[str] = []
    for path in REQUIRED_FILES:
        if not path.exists():
            errors.append(f"missing file: {path}")
        elif path.is_file() and path.stat().st_size <= 0:
            errors.append(f"empty file: {path}")

    if MONOGRAPH_MD.exists():
        text = MONOGRAPH_MD.read_text(encoding="utf-8")
        for heading in REQUIRED_HEADINGS:
            if heading not in text:
                errors.append(f"missing heading: {heading}")

    if MONOGRAPH_TEX.exists():
        tex = MONOGRAPH_TEX.read_text(encoding="utf-8")
        for needle in [
            "\\begin{document}",
            "\\begin{tikzpicture}",
            "inventory_numeric.csv",
            "p2r_frontier_numeric.csv",
            "uplop3_runtime_class_counts.csv",
        ]:
            if needle not in tex:
                errors.append(f"tex missing token: {needle}")

    if errors:
        for err in errors:
            print(err)
        return 1

    print("monograph_assets_ok")
    print(f"processed_dir={PROCESSED}")
    print(f"required_files={len(REQUIRED_FILES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
