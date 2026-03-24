#!/usr/bin/env python3
"""
Patch one or more specific PLOP3 instruction occurrences into UPLOP3 by
flipping the validated opcode byte from 0x1c to 0x9c.
"""

from __future__ import annotations

import argparse
import pathlib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--occurrence",
        type=int,
        action="append",
        required=True,
        help="1-based occurrence to patch; may be specified multiple times",
    )
    args = parser.parse_args()

    for occ in args.occurrence:
        if occ < 1:
            raise SystemExit("--occurrence must be >= 1")

    in_path = pathlib.Path(args.input)
    out_path = pathlib.Path(args.output)
    data = bytearray(in_path.read_bytes())

    marker = bytes.fromhex("1c78000000000000")
    hits: list[int] = []
    start = 0
    while True:
        idx = data.find(marker, start)
        if idx < 0:
            break
        hits.append(idx)
        start = idx + 1

    patched_offsets: list[int] = []
    for occ in args.occurrence:
        if len(hits) < occ:
            raise SystemExit(
                f"wanted occurrence {occ}, but found only {len(hits)} "
                f"matches for {marker.hex()} in {in_path}"
            )
        idx = hits[occ - 1]
        data[idx] = 0x9C
        patched_offsets.append(idx)
    out_path.write_bytes(bytes(data))

    print(f"input={in_path}")
    print(f"output={out_path}")
    print(f"match_count={len(hits)}")
    print(
        "patched_occurrences="
        + ",".join(str(occ) for occ in args.occurrence)
    )
    print(
        "offsets="
        + ",".join(f"0x{offset:x}" for offset in patched_offsets)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
