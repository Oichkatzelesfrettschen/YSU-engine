#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re


PATTERN_RE = re.compile(r"^pattern=(\d+)$")
LABEL_RE = re.compile(r"^- ([^:]+):$")
REL_RE = re.compile(r"^\s+relation=(.+)$")


def parse_summary(path: pathlib.Path) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    pattern = None
    label = None
    for raw in path.read_text().splitlines():
        if m := PATTERN_RE.match(raw):
            pattern = m.group(1)
            out.setdefault(pattern, {})
            label = None
            continue
        if m := LABEL_RE.match(raw):
            label = m.group(1)
            continue
        if pattern is not None and label is not None and (m := REL_RE.match(raw)):
            out[pattern][label] = m.group(1)
    return out


def class_for(label: str, parsed: dict[str, dict[str, str]]) -> str:
    vals = [parsed.get(str(i), {}).get(label, "n/a") for i in range(4)]
    if any(v == "n/a" for v in vals):
        return "runtime_blocked"
    if all(v == "same_as_baseline" for v in vals):
        return "inert"
    if any(v == "diff_from_baseline" for v in vals):
        if all(v in {"same_as_baseline", "diff_from_baseline"} for v in vals):
            return "stable_but_different"
    return "mixed"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("entries", nargs="+", help="name=summary_path")
    args = parser.parse_args()

    lines = ["uplop3_runtime_class_matrix", "===========================", ""]
    for entry in args.entries:
        name, path_str = entry.split("=", 1)
        parsed = parse_summary(pathlib.Path(path_str))
        labels = sorted({label for p in parsed.values() for label in p.keys() if label != "baseline"})
        lines.append(f"context={name}")
        for label in labels:
            cls = class_for(label, parsed)
            per_pat = ", ".join(f"p{k}={parsed.get(str(k), {}).get(label, 'n/a')}" for k in range(4))
            lines.append(f"- {label}: {cls} ({per_pat})")
        lines.append("")

    out_path = pathlib.Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
