#!/usr/bin/env python3
"""
Mine mnemonic chains and anchor neighborhoods from cuobjdump/nvdisasm SASS.
"""

from __future__ import annotations

import argparse
import collections
import csv
import pathlib
import re
from typing import Iterable


SASS_LINE_RE = re.compile(r"/\*[^*]+\*/\s+([A-Z][A-Z0-9_.]*)")


def iter_sass_files(paths: list[pathlib.Path]) -> Iterable[pathlib.Path]:
    for path in paths:
        if path.is_file() and path.suffix == ".sass":
            yield path
        elif path.is_dir():
            yield from sorted(path.rglob("*.sass"))


def parse_mnemonics(path: pathlib.Path) -> list[str]:
    mnemonics: list[str] = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            match = SASS_LINE_RE.search(line)
            if match:
                mnemonics.append(match.group(1))
    return mnemonics


def ngrams(items: list[str], n: int) -> collections.Counter[tuple[str, ...]]:
    counter: collections.Counter[tuple[str, ...]] = collections.Counter()
    if len(items) < n:
        return counter
    for idx in range(len(items) - n + 1):
        counter[tuple(items[idx : idx + n])] += 1
    return counter


def anchor_windows(
    items: list[str], anchors: set[str], radius: int
) -> collections.Counter[tuple[str, ...]]:
    counter: collections.Counter[tuple[str, ...]] = collections.Counter()
    for idx, item in enumerate(items):
        if item not in anchors:
            continue
        lo = max(0, idx - radius)
        hi = min(len(items), idx + radius + 1)
        counter[tuple(items[lo:hi])] += 1
    return counter


def write_counter_csv(path: pathlib.Path, header: list[str], rows: list[list[str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Mine SASS mnemonic chains and anchor neighborhoods")
    parser.add_argument("inputs", nargs="+", help="SASS files or directories")
    parser.add_argument("--outdir", required=True, help="output directory")
    parser.add_argument("--top", type=int, default=200, help="top rows per report")
    parser.add_argument(
        "--anchors",
        default="P2R,PLOP3.LUT,ULOP3.LUT,UIADD3,HMMA.1688.F32.TF32,LDGSTS.E.BYPASS.LTC128B.128",
        help="comma-separated anchor mnemonics for neighborhood mining",
    )
    parser.add_argument("--radius", type=int, default=3, help="anchor neighborhood radius")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    sass_files = list(iter_sass_files([pathlib.Path(item) for item in args.inputs]))
    anchors = {item.strip() for item in args.anchors.split(",") if item.strip()}

    global_counts: collections.Counter[str] = collections.Counter()
    bigrams: collections.Counter[tuple[str, ...]] = collections.Counter()
    trigrams: collections.Counter[tuple[str, ...]] = collections.Counter()
    neighborhoods: collections.Counter[tuple[str, ...]] = collections.Counter()

    per_file_rows: list[list[str]] = []
    for path in sass_files:
        items = parse_mnemonics(path)
        global_counts.update(items)
        bigrams.update(ngrams(items, 2))
        trigrams.update(ngrams(items, 3))
        neighborhoods.update(anchor_windows(items, anchors, args.radius))
        per_file_rows.append([str(path), str(len(items)), str(len(set(items)))])

    write_counter_csv(
        outdir / "files.csv",
        ["path", "instruction_count", "unique_mnemonics"],
        per_file_rows,
    )
    write_counter_csv(
        outdir / "mnemonics.csv",
        ["mnemonic", "count"],
        [[k, str(v)] for k, v in global_counts.most_common(args.top)],
    )
    write_counter_csv(
        outdir / "bigrams.csv",
        ["chain", "count"],
        [[" -> ".join(k), str(v)] for k, v in bigrams.most_common(args.top)],
    )
    write_counter_csv(
        outdir / "trigrams.csv",
        ["chain", "count"],
        [[" -> ".join(k), str(v)] for k, v in trigrams.most_common(args.top)],
    )
    write_counter_csv(
        outdir / "anchor_windows.csv",
        ["window", "count"],
        [[" | ".join(k), str(v)] for k, v in neighborhoods.most_common(args.top)],
    )

    with (outdir / "summary.txt").open("w", encoding="utf-8") as handle:
        handle.write("sass_chain_mine\n")
        handle.write("================\n\n")
        handle.write(f"files={len(sass_files)}\n")
        handle.write(f"unique_mnemonics={len(global_counts)}\n")
        handle.write(f"anchors={','.join(sorted(anchors))}\n")
        handle.write("\n[top_bigrams]\n")
        for chain, count in bigrams.most_common(min(args.top, 20)):
            handle.write(f"{count}: {' -> '.join(chain)}\n")
        handle.write("\n[top_trigrams]\n")
        for chain, count in trigrams.most_common(min(args.top, 20)):
            handle.write(f"{count}: {' -> '.join(chain)}\n")
        handle.write("\n[top_anchor_windows]\n")
        for chain, count in neighborhoods.most_common(min(args.top, 20)):
            handle.write(f"{count}: {' | '.join(chain)}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
