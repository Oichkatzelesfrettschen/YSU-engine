#!/usr/bin/env python3
"""
Generate motif-driven PTX variants for the richer B2/B3 cuDNN pockets.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess

from search_p2r_ptx import entry_template, ptx_header  # type: ignore


VARIANTS = {
    "motif_b2_r2p_lea_like": (
        "",
        """
    .reg .pred q<8>;
    setp.ge.s32 p0, r1, 0;
    setp.ge.s32 p1, r2, 0;
    setp.ge.s32 p2, r3, 0;
    setp.ge.s32 p3, r4, 0;
    selp.b32 r10, 0x8, 0x0, p0;
    selp.b32 r11, 0x10, 0x0, p1;
    selp.b32 r12, 0x20, 0x0, p2;
    selp.b32 r13, 0x40, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r20, r1, 0xff00ffff;
    shl.b32 r14, r14, 16;
    or.b32 r20, r20, r14;
    setp.ne.u32 q0, r20, 0;
    setp.ne.u32 q1, r14, 0;
    setp.lt.s32 q2, r2, r3;
    setp.ge.s32 q3, r3, r4;
    and.pred q4, q0, q2;
    or.pred q5, q1, q3;
    xor.pred q6, q4, q5;
    selp.b32 r15, 1, 0, q4;
    mad.lo.u32 r16, r15, 4, r2;
    mad.lo.u32 r17, r16, 4, r3;
    add.u32 r18, r17, r4;
    mov.u32 r20, r18;
""",
    ),
    "motif_b3_barsync_uldc_like": (
        ".shared .align 8 .b64 smem[32];",
        """
    .reg .pred q<8>;
    cvta.shared.u64 rd7, smem;
    st.shared.u64 [rd7], rd3;
    bar.sync 0;
    ld.shared.u64 rd7, [rd7];
    cvt.u32.u64 r5, rd7;
    setp.lt.s32 p0, r5, -16;
    setp.lt.s32 p1, r5, -32;
    setp.lt.s32 p2, r5, -48;
    setp.lt.s32 p3, r5, -64;
    selp.b32 r10, 0x8, 0x0, p0;
    selp.b32 r11, 0x10, 0x0, p1;
    selp.b32 r12, 0x20, 0x0, p2;
    selp.b32 r13, 0x40, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r20, r1, 0x00ffffff;
    shl.b32 r14, r14, 24;
    or.b32 r20, r20, r14;
    setp.ne.u32 q0, r20, 0;
    setp.lt.s32 q1, r2, r3;
    and.pred q2, q0, q1;
    selp.b32 r15, 0x78, 0x0, q2;
    add.u32 r16, r15, r4;
    mov.u32 r20, r16;
""",
    ),
    "motif_b23_ldgsts_bar_like": (
        ".shared .align 16 .b32 smem32[64];",
        """
    .reg .pred q<8>;
    cvta.shared.u64 rd7, smem32;
    st.shared.u32 [rd7], r1;
    bar.sync 0;
    ld.shared.u32 r5, [rd7];
    setp.lt.s32 p0, r5, -16;
    setp.lt.s32 p1, r5, -32;
    setp.lt.s32 p2, r5, -48;
    setp.lt.s32 p3, r5, -64;
    selp.b32 r10, 0x8, 0x0, p0;
    selp.b32 r11, 0x10, 0x0, p1;
    selp.b32 r12, 0x20, 0x0, p2;
    selp.b32 r13, 0x40, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r15, r1, 0xff00ffff;
    shl.b32 r16, r14, 16;
    or.b32 r17, r15, r16;
    setp.ne.u32 q0, r17, 0;
    setp.ne.u32 q1, r14, 0;
    and.pred q2, q0, q1;
    selp.b32 r18, 0x78, 0x0, q2;
    add.u32 r20, r18, r17;
""",
    ),
    "motif_b2_r2p_lea_hix_exact": (
        ".shared .align 8 .b64 smem_lea[32];",
        """
    .reg .pred q<8>;
    cvta.shared.u64 rd7, smem_lea;
    st.shared.u64 [rd7], rd3;
    ld.shared.u64 rd7, [rd7];
    cvt.u32.u64 r5, rd7;
    setp.ge.s32 p0, r1, r2;
    setp.ge.s32 p1, r2, r3;
    setp.ge.s32 p2, r3, r4;
    setp.ge.s32 p3, r4, r5;
    selp.b32 r10, 0x8, 0x0, p0;
    selp.b32 r11, 0x10, 0x0, p1;
    selp.b32 r12, 0x20, 0x0, p2;
    selp.b32 r13, 0x40, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r15, r5, 0xff00ffff;
    shl.b32 r16, r14, 16;
    or.b32 r17, r15, r16;
    setp.ne.u32 q0, r17, 0;
    selp.b32 r18, 0x78, 0x0, q0;
    shl.b32 r19, r18, 2;
    add.u32 r20, r19, r2;
    mad.lo.u32 r21, r20, 8, r3;
    mad.hi.u32 r22, r20, 8, r4;
    add.u32 r20, r21, r22;
""",
    ),
    "motif_b3_barsync_iadd3_r2p_exact": (
        ".shared .align 8 .b64 smem_bar[32];",
        """
    .reg .pred q<8>;
    cvta.shared.u64 rd7, smem_bar;
    st.shared.u64 [rd7], rd3;
    bar.sync 0;
    ld.shared.u64 rd7, [rd7];
    cvt.u32.u64 r5, rd7;
    setp.lt.s32 p0, r5, -16;
    setp.lt.s32 p1, r5, -32;
    setp.lt.s32 p2, r5, -48;
    setp.lt.s32 p3, r5, -64;
    selp.b32 r10, 0x8, 0x0, p0;
    selp.b32 r11, 0x10, 0x0, p1;
    selp.b32 r12, 0x20, 0x0, p2;
    selp.b32 r13, 0x40, 0x0, p3;
    add.u32 r14, r10, r11;
    add.u32 r14, r14, r12;
    add.u32 r14, r14, r13;
    and.b32 r15, r5, 0x00ffffff;
    shl.b32 r16, r14, 24;
    or.b32 r17, r15, r16;
    setp.ne.u32 q0, r17, 0;
    selp.b32 r18, 0x78, 0x0, q0;
    add.u32 r19, r18, r2;
    add.u32 r20, r19, r3;
    add.u32 r20, r20, r4;
""",
    ),
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
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary = ["p2r_ptx_b23_motif", "==================", ""]
    for name, (prelude, body) in VARIANTS.items():
        ptx = outdir / f"{name}.ptx"
        cubin = outdir / f"{name}.cubin"
        sass = outdir / f"{name}.sass"
        ptx.write_text(
            entry_template(name, body, args.ptx_version, args.target, prelude),
            encoding="utf-8",
        )
        cmd = [args.ptxas]
        if args.debug:
            cmd.append("-g")
        cmd.extend(["-arch=sm_89", str(ptx), "-o", str(cubin)])
        try:
            run_checked(cmd)
            sass_text = subprocess.run(
                [args.cuobjdump, "-sass", str(cubin)],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            sass.write_text(sass_text, encoding="utf-8")
            summary.append(
                f"- {name}: byte_p2r={any(tag in sass_text for tag in ('P2R.B1','P2R.B2','P2R.B3'))}, "
                f"plain_p2r={'P2R ' in sass_text}, "
                f"r2p={'R2P' in sass_text}, "
                f"bar={any(tok in sass_text for tok in ('BAR.SYNC','BSSY','BSYNC','WARPSYNC'))}, "
                f"uldc={'ULDC' in sass_text}, "
                f"lds={'LDS' in sass_text}, "
                f"ldgsts={'LDGSTS' in sass_text}"
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
