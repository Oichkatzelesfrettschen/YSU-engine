#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess


SUM_RE = re.compile(r"^sum=(.+)$", re.MULTILINE)
OUT_RE = re.compile(r"^out\[(\d+)\]=(.*)$", re.MULTILINE)


def run_case(runner: pathlib.Path, cubin: pathlib.Path, kernel: str, pattern: int) -> str:
    proc = subprocess.run(
        [str(runner), str(cubin), kernel, str(pattern)],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"runner failed for pattern={pattern}: {proc.stderr.strip()}")
    return proc.stdout


def parse_out(text: str) -> tuple[str | None, dict[int, str]]:
    sum_m = SUM_RE.search(text)
    outs = {int(idx): val.strip() for idx, val in OUT_RE.findall(text)}
    return (sum_m.group(1).strip() if sum_m else None, outs)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runner", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("labels_and_cubins", nargs="+")
    ap.add_argument("--pattern-start", type=int, default=100)
    ap.add_argument("--count", type=int, default=32)
    args = ap.parse_args()

    if len(args.labels_and_cubins) % 2 != 0:
        raise SystemExit("labels_and_cubins must be pairs of <label> <cubin>")

    runner = pathlib.Path(args.runner)
    baseline = pathlib.Path(args.baseline)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    cases = []
    items = args.labels_and_cubins
    for i in range(0, len(items), 2):
        cases.append((items[i], pathlib.Path(items[i + 1])))

    lines = ["uplop3_diff_fuzz", "================", ""]
    for offset in range(args.count):
        pattern = args.pattern_start + offset
        base_text = run_case(runner, baseline, args.kernel, pattern)
        base_sum, base_outs = parse_out(base_text)
        lines.append(f"pattern={pattern}")
        lines.append(f"- baseline_sum={base_sum}")
        for label, cubin in cases:
            text = run_case(runner, cubin, args.kernel, pattern)
            case_sum, case_outs = parse_out(text)
            changed_indices = [idx for idx, val in case_outs.items() if base_outs.get(idx) != val]
            sum_relation = "same_sum" if case_sum == base_sum else "diff_sum"
            out_relation = "same_out_prefix" if not changed_indices else "diff_out_prefix"
            lines.append(
                f"- {label}: {sum_relation}, {out_relation}, changed_indices="
                + (",".join(str(i) for i in changed_indices[:16]) if changed_indices else "none")
            )
        lines.append("")

    (outdir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
