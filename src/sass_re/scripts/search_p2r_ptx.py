#!/usr/bin/env python3
"""
Generate and test direct PTX variants for the P2R.B* frontier.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess


def ptx_header(ptx_version: str, target: str) -> str:
    return f""".version {ptx_version}
.target {target}
.address_size 64
"""


def entry_template(name: str, body: str, ptx_version: str, target: str, prelude: str = "") -> str:
    return (
        ptx_header(ptx_version, target)
        + f"""
{prelude}
.visible .entry {name}(
    .param .u64 out_ptr,
    .param .u64 in_ptr,
    .param .u64 seed_ptr
)
{{
    .reg .pred p<16>;
    .reg .b32 r<32>;
    .reg .b64 rd<8>;

    ld.param.u64 rd0, [out_ptr];
    ld.param.u64 rd1, [in_ptr];
    ld.param.u64 rd2, [seed_ptr];
    mov.u32 r0, %tid.x;
    mul.wide.u32 rd3, r0, 4;
    add.s64 rd4, rd2, rd3;
    add.s64 rd5, rd1, rd3;
    ld.global.u32 r1, [rd4];
    ld.global.u32 r2, [rd5];
    add.s64 rd6, rd1, 128;
    add.s64 rd6, rd6, rd3;
    ld.global.u32 r3, [rd6];
    add.s64 rd7, rd1, 256;
    add.s64 rd7, rd7, rd3;
    ld.global.u32 r4, [rd7];
{body}
    add.s64 rd0, rd0, rd3;
    st.global.u32 [rd0], r20;
    ret;
}}
"""
    )


VARIANTS = {
    "predlogic_selpack_b1": ("", """
    setp.gt.s32 p0, r2, 0;
    setp.lt.s32 p1, r3, 0;
    setp.ne.s32 p2, r4, 0;
    and.pred p3, p0, !p1;
    or.pred  p4, p1, p2;
    xor.pred p5, p3, p4;
    and.pred p6, p5, p0;
    selp.b32 r10, 0x1, 0x0, p0;
    selp.b32 r11, 0x2, 0x0, p1;
    selp.b32 r12, 0x4, 0x0, p2;
    selp.b32 r13, 0x8, 0x0, p3;
    selp.b32 r14, 0x10, 0x0, p4;
    selp.b32 r15, 0x20, 0x0, p5;
    selp.b32 r16, 0x40, 0x0, p6;
    add.u32 r17, r10, r11;
    add.u32 r17, r17, r12;
    add.u32 r17, r17, r13;
    add.u32 r17, r17, r14;
    add.u32 r17, r17, r15;
    add.u32 r17, r17, r16;
    and.b32 r18, r1, 0xffff80ff;
    shl.b32 r19, r17, 8;
    or.b32 r20, r18, r19;
"""),
    "predlogic_tripack_b23": ("", """
    setp.gt.s32 p0, r2, 3;
    setp.le.s32 p1, r3, 1;
    setp.eq.s32 p2, r4, 9;
    xor.pred p3, p0, p1;
    or.pred  p4, p1, p2;
    and.pred p5, p3, p4;
    selp.b32 r10, 0x1, 0x0, p0;
    selp.b32 r11, 0x2, 0x0, p1;
    selp.b32 r12, 0x4, 0x0, p2;
    selp.b32 r13, 0x8, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r15, r1, 0xff00ffff;
    shl.b32 r16, r14, 16;
    or.b32 r17, r15, r16;
    selp.b32 r10, 0x1, 0x0, p4;
    selp.b32 r11, 0x2, 0x0, p5;
    selp.b32 r12, 0x4, 0x0, p0;
    selp.b32 r13, 0x8, 0x0, p1;
    add.u32 r18, r10, r11;
    add.u32 r18, r18, r12;
    add.u32 r18, r18, r13;
    and.b32 r19, r17, 0x00ffffff;
    shl.b32 r18, r18, 24;
    or.b32 r20, r19, r18;
"""),
    "predlogic_samecarrier_b1b2": ("", """
    setp.gt.s32 p0, r2, 0;
    setp.lt.s32 p1, r3, 0;
    setp.ne.s32 p2, r4, 0;
    and.pred p3, p0, p2;
    or.pred  p4, p1, p3;
    xor.pred p5, p4, p0;
    and.pred p6, p5, p2;
    selp.b32 r10, 0x1, 0x0, p0;
    selp.b32 r11, 0x2, 0x0, p1;
    selp.b32 r12, 0x4, 0x0, p2;
    selp.b32 r13, 0x8, 0x0, p3;
    selp.b32 r14, 0x10, 0x0, p4;
    selp.b32 r15, 0x20, 0x0, p5;
    selp.b32 r16, 0x40, 0x0, p6;
    add.u32 r17, r10, r11;
    add.u32 r17, r17, r12;
    add.u32 r17, r17, r13;
    add.u32 r17, r17, r14;
    add.u32 r17, r17, r15;
    add.u32 r17, r17, r16;
    and.b32 r18, r1, 0xffff80ff;
    shl.b32 r19, r17, 8;
    or.b32 r20, r18, r19;
    selp.b32 r10, 0x1, 0x0, p6;
    selp.b32 r11, 0x2, 0x0, p5;
    selp.b32 r12, 0x4, 0x0, p4;
    selp.b32 r13, 0x8, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    or.b32 r14, r14, 0x80;
    and.b32 r15, r20, 0xff00ffff;
    shl.b32 r16, r14, 16;
    or.b32 r20, r15, r16;
"""),
    "mined_b1_isept_lea_like": ("", """
    add.u32 r5, r2, r3;
    mad.lo.u32 r6, r4, 4, r1;
    setp.lt.s32 p0, r2, r3;
    setp.ge.s32 p1, r4, r2;
    setp.lt.s32 p2, r5, r6;
    setp.ge.s32 p3, r6, r1;
    or.pred p4, p0, p2;
    and.pred p5, p1, p3;
    xor.pred p6, p4, p5;
    selp.b32 r10, 0x1, 0x0, p0;
    selp.b32 r11, 0x2, 0x0, p1;
    selp.b32 r12, 0x4, 0x0, p2;
    selp.b32 r13, 0x8, 0x0, p3;
    selp.b32 r14, 0x10, 0x0, p4;
    selp.b32 r15, 0x20, 0x0, p5;
    selp.b32 r16, 0x40, 0x0, p6;
    add.u32 r17, r10, r11;
    add.u32 r17, r17, r12;
    add.u32 r17, r17, r13;
    add.u32 r17, r17, r14;
    add.u32 r17, r17, r15;
    add.u32 r17, r17, r16;
    and.b32 r18, r1, 0xffff80ff;
    shl.b32 r19, r17, 8;
    or.b32 r20, r18, r19;
"""),
    "mined_b23_shared_bar_like": (".shared .align 8 .b64 smem[32];", """
    cvta.shared.u64 rd7, smem;
    st.shared.u64 [rd7], rd3;
    bar.sync 0;
    ld.shared.u64 rd7, [rd7];
    cvt.u32.u64 r5, rd7;
    shr.u32 r6, r5, 5;
    setp.ge.s32 p0, r5, r2;
    setp.ge.s32 p1, r6, r3;
    setp.lt.s32 p2, r4, r5;
    setp.ne.s32 p3, r6, r1;
    or.pred p4, p0, p1;
    and.pred p5, p2, p3;
    xor.pred p6, p4, p5;
    selp.b32 r10, 0x1, 0x0, p0;
    selp.b32 r11, 0x2, 0x0, p1;
    selp.b32 r12, 0x4, 0x0, p2;
    selp.b32 r13, 0x8, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r15, r1, 0xff00ffff;
    shl.b32 r16, r14, 16;
    or.b32 r17, r15, r16;
    selp.b32 r10, 0x1, 0x0, p4;
    selp.b32 r11, 0x2, 0x0, p5;
    selp.b32 r12, 0x4, 0x0, p6;
    selp.b32 r13, 0x8, 0x0, p0;
    add.u32 r18, r10, r11;
    add.u32 r18, r18, r12;
    add.u32 r18, r18, r13;
    and.b32 r19, r17, 0x00ffffff;
    shl.b32 r18, r18, 24;
    or.b32 r20, r19, r18;
"""),
}


def run_checked(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--outdir", required=True)
    parser.add_argument("--ptxas", default="/opt/cuda/bin/ptxas")
    parser.add_argument("--cuobjdump", default="cuobjdump")
    parser.add_argument("--ptx-version", default="8.8")
    parser.add_argument("--target", default="sm_89")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary = ["p2r_ptx_search", "==============", ""]
    for name, value in VARIANTS.items():
        prelude, body = value
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
            has_b = any(tag in sass_text for tag in ("P2R.B1", "P2R.B2", "P2R.B3"))
            has_plain = "P2R " in sass_text
            has_plop3 = "PLOP3.LUT" in sass_text
            summary.append(
                f"- {name}: byte_p2r={has_b}, plain_p2r={has_plain}, plop3={has_plop3}"
            )
        except subprocess.CalledProcessError as exc:
            summary.append(f"- {name}: FAIL")
            (outdir / f"{name}.log").write_text(
                (exc.stdout or "") + "\n" + (exc.stderr or ""), encoding="utf-8"
            )

    (outdir / "summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(outdir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
