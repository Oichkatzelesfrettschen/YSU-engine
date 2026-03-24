#!/usr/bin/env python3
"""
Summarize per-function mnemonic counts from cuobjdump -sass output.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys


FUNC_RE = re.compile(r"^\s*Function\s*:\s*(\S+)")
OP_RE = re.compile(r"^\s*/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)")


def summarize(path: pathlib.Path) -> dict[str, collections.Counter[str]]:
    functions: dict[str, collections.Counter[str]] = {}
    current = "<unknown>"
    functions[current] = collections.Counter()
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            func_match = FUNC_RE.match(line)
            if func_match:
                current = func_match.group(1)
                functions.setdefault(current, collections.Counter())
                continue
            op_match = OP_RE.match(line)
            if op_match:
                functions[current][op_match.group(1)] += 1
    return functions


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Summarize SASS mnemonics by function")
    parser.add_argument("sass", help="path to .sass file")
    parser.add_argument(
        "--focus",
        default="TEX,TLD,FFMA,FADD,FMUL,SULD,SUST",
        help="comma-separated mnemonics to print first",
    )
    args = parser.parse_args(argv)

    focus = [item.strip() for item in args.focus.split(",") if item.strip()]
    functions = summarize(pathlib.Path(args.sass))

    for name in sorted(functions):
        counts = functions[name]
        total = sum(counts.values())
        if total == 0:
            continue
        print(f"{name}: total={total}")
        for key in focus:
            if counts.get(key, 0):
                print(f"  {key}: {counts[key]}")
        top = counts.most_common(8)
        tail = [f"{op}={count}" for op, count in top if op not in focus]
        if tail:
            print("  top:", ", ".join(tail))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
