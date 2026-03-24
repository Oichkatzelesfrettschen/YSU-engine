#!/usr/bin/env python3
"""
Constrained PTX search seeded from mined P2R.B2/B3 library motifs.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess

from search_p2r_ptx import entry_template  # type: ignore


def build_body(seed: dict[str, object]) -> tuple[str, str]:
    prelude = ""
    lines: list[str] = [".reg .pred q<8>;"]

    if seed["has_uldc"]:
        prelude += ".const .align 8 .u64 ctab[4] = {0, 8, 16, 24};\n"
        lines.append("    ld.const.u64 rd7, [ctab];")
        lines.append("    cvt.u32.u64 r5, rd7;")
    if seed["has_lds64"]:
        prelude += ".shared .align 8 .b64 smem64[32];\n"
        lines.extend([
            "    cvta.shared.u64 rd7, smem64;",
            "    st.shared.u64 [rd7], rd3;",
        ])
    elif seed["has_bar_sync"] or seed["has_ldgsts"]:
        prelude += ".shared .align 4 .b32 smem32[64];\n"
        lines.extend([
            "    cvta.shared.u64 rd7, smem32;",
            "    st.shared.u32 [rd7], r1;",
        ])

    if seed["has_bar_sync"]:
        lines.append("    bar.sync 0;")
    if seed["has_lds64"]:
        lines.extend([
            "    ld.shared.u64 rd7, [rd7];",
            "    cvt.u32.u64 r5, rd7;",
        ])
    elif seed["has_bar_sync"] or seed["has_ldgsts"]:
        lines.append("    ld.shared.u32 r5, [rd7];")
    else:
        lines.append("    add.u32 r5, r1, r2;")

    pred_kind = str(seed["pred_kind"])
    cmp = "ge" if pred_kind == "ISETP.GE" else "lt"
    for idx, reg in enumerate(("r1", "r2", "r3", "r4")):
        lines.append(f"    setp.{cmp}.s32 p{idx}, r5, {reg};")

    lines.extend([
        "    selp.b32 r10, 0x8, 0x0, p0;",
        "    selp.b32 r11, 0x10, 0x0, p1;",
        "    selp.b32 r12, 0x20, 0x0, p2;",
        "    selp.b32 r13, 0x40, 0x0, p3;",
        "    add.u32 r14, r10, r11;",
        "    add.u32 r14, r14, r12;",
        "    add.u32 r14, r14, r13;",
    ])

    if seed["target"] == "P2R.B3":
        lines.extend([
            "    and.b32 r15, r1, 0x00ffffff;",
            "    shl.b32 r16, r14, 24;",
            "    or.b32 r17, r15, r16;",
        ])
    else:
        lines.extend([
            "    and.b32 r15, r1, 0xff00ffff;",
            "    shl.b32 r16, r14, 16;",
            "    or.b32 r17, r15, r16;",
        ])

    if seed["has_r2p"] or seed["has_lea"]:
        lines.extend([
            "    setp.ne.u32 q0, r17, 0;",
            "    selp.b32 r18, 0x78, 0x0, q0;",
            "    shl.b32 r19, r18, 2;",
            "    add.u32 r20, r19, r2;",
            "    mad.lo.u32 r21, r20, 8, r3;",
            "    mad.hi.u32 r22, r20, 8, r4;",
            "    add.u32 r20, r21, r22;",
        ])
    else:
        lines.append("    mov.u32 r20, r17;")

    return prelude, "\n".join(lines)


def run_checked(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", required=True)
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--ptxas", default="/opt/cuda/bin/ptxas")
    parser.add_argument("--cuobjdump", default="cuobjdump")
    parser.add_argument("--ptx-version", default="8.8")
    parser.add_argument("--target", default="sm_89")
    parser.add_argument("--limit", type=int, default=24)
    parser.add_argument("--unique-classes", action="store_true")
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.seeds).read_text(encoding="utf-8"))
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary = ["p2r_ptx_cegis", "==============", ""]
    summary.append(f"- seeds: {args.seeds}")
    seeds = list(payload["seeds"])
    seeds.sort(
        key=lambda s: (
            int(s["has_r2p"]) + int(s["has_bar_sync"]) + int(s["has_uldc"]) + int(s["has_lds64"]) + int(s["has_ldgsts"]) + int(s["has_lea"]),
            str(s["class"]),
        ),
        reverse=True,
    )
    if args.unique_classes:
        unique = []
        seen = set()
        for seed in seeds:
            cls = str(seed["class"])
            if cls in seen:
                continue
            unique.append(seed)
            seen.add(cls)
        seeds = unique

    for idx, seed in enumerate(seeds[: args.limit]):
        name = f"seed_{idx:02d}_{seed['target'].replace('.', '_').lower()}"
        prelude, body = build_body(seed)
        ptx = outdir / f"{name}.ptx"
        cubin = outdir / f"{name}.cubin"
        sass = outdir / f"{name}.sass"
        ptx.write_text(
            entry_template(name, body, args.ptx_version, args.target, prelude),
            encoding="utf-8",
        )
        try:
            run_checked([args.ptxas, "-arch=sm_89", str(ptx), "-o", str(cubin)])
            sass_text = subprocess.run(
                [args.cuobjdump, "-sass", str(cubin)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            sass.write_text(sass_text, encoding="utf-8")
            summary.append(
                f"- {name}: target={seed['target']}, class={seed['class']}, "
                f"byte_p2r={any(tag in sass_text for tag in ('P2R.B1','P2R.B2','P2R.B3'))}, "
                f"plain_p2r={'P2R ' in sass_text}, r2p={'R2P' in sass_text}, "
                f"bar={('BAR.SYNC' in sass_text)}, uldc={('ULDC' in sass_text)}, "
                f"lds={('LDS' in sass_text)}, ldgsts={('LDGSTS' in sass_text)}"
            )
        except subprocess.CalledProcessError as exc:
            summary.append(f"- {name}: FAIL")
            (outdir / f"{name}.log").write_text((exc.stdout or "") + "\n" + (exc.stderr or ""), encoding="utf-8")

    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
