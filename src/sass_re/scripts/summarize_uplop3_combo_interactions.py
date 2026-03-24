#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import re
import sys


LABELS = [
    "baseline",
    "occ1",
    "occ2",
    "occ5",
    "occ1_occ2",
    "occ1_occ5",
    "occ2_occ5",
    "occ1_occ2_occ5",
]


def extract_case(block: str, label: str) -> tuple[str, str] | None:
    match = re.search(
        rf"- {re.escape(label)}:\n"
        rf"  rc=0\n"
        rf"(?:  relation=[^\n]+\n)?"
        rf"  kernel=[^\n]+\n"
        rf"  pattern=\d+\n"
        rf"  sum=(\d+)\n"
        rf"  out\[0\]=0x([0-9a-fA-F]+)",
        block,
        re.S,
    )
    if not match:
        return None
    return match.group(1), match.group(2).lower()


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: summarize_uplop3_combo_interactions.py <summary.txt> <outdir>",
            file=sys.stderr,
        )
        return 2

    summary_path = pathlib.Path(sys.argv[1])
    outdir = pathlib.Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)

    text = summary_path.read_text()
    lines: list[str] = []
    lines.append("uplop3_combo_interactions")
    lines.append("========================")
    lines.append("")

    for pattern in range(4):
        block = text.split(f"pattern={pattern}\n", 1)[1]
        if pattern < 3:
            block = block.split(f"pattern={pattern + 1}\n", 1)[0]

        cases = {
            label: extract_case(block, label)
            for label in LABELS
            if extract_case(block, label) is not None
        }
        lines.append(f"pattern={pattern}")
        for label, payload in cases.items():
            lines.append(f"- {label}: sum={payload[0]} out0=0x{payload[1]}")

        occ1 = cases.get("occ1")
        occ2 = cases.get("occ2")
        occ5 = cases.get("occ5")
        occ12 = cases.get("occ1_occ2")
        occ15 = cases.get("occ1_occ5")
        occ25 = cases.get("occ2_occ5")
        occ125 = cases.get("occ1_occ2_occ5")

        if occ12 == occ1 and occ15 == occ1 and occ125 == occ1:
            lines.append("- interaction: occ1 dominates this pattern")
        elif occ15 == occ5 and occ25 == occ5 and occ125 == occ5:
            lines.append("- interaction: occ5 dominates this pattern")
        elif occ12 == occ2 and occ25 == occ2 and occ125 == occ2:
            lines.append("- interaction: occ2 dominates this pattern")
        elif occ12 == occ2 and occ25 == occ2 and occ15 == cases.get("baseline"):
            lines.append("- interaction: occ2 dominates while occ1 cancels occ5")
        elif occ15 == occ1 and occ125 == occ1 and occ25 == occ5:
            lines.append("- interaction: occ1 and occ5 produce distinct live families")
        else:
            lines.append("- interaction: mixed / nontrivial composition")
        lines.append("")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
