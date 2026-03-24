#!/usr/bin/env python3
"""
Patch a specific plain-P2R instruction pair inside a cubin blob.
"""

from __future__ import annotations

import argparse
import pathlib
import sys


def pair_bytes(word0: str, word1: str) -> bytes:
    return bytes.fromhex(word0.removeprefix("0x"))[::-1] + bytes.fromhex(word1.removeprefix("0x"))[::-1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--orig-word0", required=True)
    parser.add_argument("--orig-word1", required=True)
    parser.add_argument("--patched-word0", required=True)
    parser.add_argument("--patched-word1", required=True)
    parser.add_argument("--occurrence", type=int, default=1)
    args = parser.parse_args()

    if args.occurrence < 1:
        raise SystemExit("--occurrence must be >= 1")

    in_path = pathlib.Path(args.input)
    out_path = pathlib.Path(args.output)
    data = bytearray(in_path.read_bytes())

    orig = pair_bytes(args.orig_word0, args.orig_word1)
    patched = pair_bytes(args.patched_word0, args.patched_word1)

    hits = []
    start = 0
    while True:
        idx = data.find(orig, start)
        if idx < 0:
            break
        hits.append(idx)
        start = idx + 1

    if len(hits) < args.occurrence:
        raise SystemExit(
            f"wanted occurrence {args.occurrence}, but found only {len(hits)} matches for "
            f"{args.orig_word0}/{args.orig_word1} in {in_path}"
        )

    idx = hits[args.occurrence - 1]
    data[idx : idx + len(orig)] = patched
    out_path.write_bytes(bytes(data))

    print(f"input={in_path}")
    print(f"output={out_path}")
    print(f"match_count={len(hits)}")
    print(f"patched_occurrence={args.occurrence}")
    print(f"offset=0x{idx:x}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
