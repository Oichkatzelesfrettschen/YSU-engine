#!/bin/sh
# Build and compare a dedicated multi-TU dlto tranche.
#
# Usage: sh validate_dlto_tranche.sh [output_dir]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NVCC="${NVCC:-nvcc}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
OUTDIR="${1:-$ROOT/results/runs/dlto_tranche_$(date +%Y%m%d_%H%M%S)}"
ARCH="sm_89"

mkdir -p "$OUTDIR"

ENTRY="$ROOT/lto/dlto_cross_tu_kernel.cu"
HELPER_A="$ROOT/lto/dlto_stage_helper_bits.cu"
HELPER_B="$ROOT/lto/dlto_stage_helper_mix.cu"
RUNNER="$ROOT/runners/dlto_cross_tu_runner.cu"
SUMMARY="$OUTDIR/summary.txt"

build_variant() {
    label="$1"
    shift
    flags="$*"
    vdir="$OUTDIR/$label"
    mkdir -p "$vdir"

    $NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo -dc $flags "$ENTRY" -o "$vdir/entry.o" >"$vdir/build.log" 2>&1
    $NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo -dc $flags "$HELPER_A" -o "$vdir/helper_a.o" >>"$vdir/build.log" 2>&1
    $NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo -dc $flags "$HELPER_B" -o "$vdir/helper_b.o" >>"$vdir/build.log" 2>&1
    $NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo $flags "$RUNNER" "$vdir/entry.o" "$vdir/helper_a.o" "$vdir/helper_b.o" -o "$vdir/dlto_runner" >>"$vdir/build.log" 2>&1
    "$vdir/dlto_runner" >"$vdir/run.log" 2>&1
    cuobjdump -sass "$vdir/dlto_runner" >"$vdir/dlto_runner.sass" 2>"$vdir/cuobjdump.log" || true
    python3 "$SCRIPT_DIR/sass_function_summary.py" "$vdir/dlto_runner.sass" \
        --focus "CALL,RET,UIADD3,UIMAD,ULEA,UPRMT,PLOP3.LUT,LOP3.LUT,SHF.L.U64.HI" \
        >"$vdir/function_summary.txt" 2>&1 || true
}

build_variant "no_lto" "-O3"
build_variant "with_dlto" "-O3 -dlto"

for label in no_lto with_dlto; do
    python3 - "$OUTDIR/$label/dlto_runner.sass" "$OUTDIR/$label/mnemonics.txt" <<'PY'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
op_re = re.compile(r'^\s+/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)', re.M)
text = src.read_text(encoding='utf-8', errors='ignore')
ops = sorted(set(op_re.findall(text)))
dst.write_text("".join(f"{op}\n" for op in ops), encoding='utf-8')
PY
done

{
    echo "dlto_tranche"
    echo "============"
    echo
    echo "no_lto unique mnemonics: $(wc -l < "$OUTDIR/no_lto/mnemonics.txt" 2>/dev/null || echo 0)"
    echo "with_dlto unique mnemonics: $(wc -l < "$OUTDIR/with_dlto/mnemonics.txt" 2>/dev/null || echo 0)"
    echo
    echo "new in with_dlto vs no_lto:"
    comm -23 "$OUTDIR/with_dlto/mnemonics.txt" "$OUTDIR/no_lto/mnemonics.txt" 2>/dev/null || true
    echo
    echo "dropped in with_dlto vs no_lto:"
    comm -13 "$OUTDIR/with_dlto/mnemonics.txt" "$OUTDIR/no_lto/mnemonics.txt" 2>/dev/null || true
    echo
    echo "function summaries:"
    echo "-- no_lto --"
    cat "$OUTDIR/no_lto/function_summary.txt"
    echo
    echo "-- with_dlto --"
    cat "$OUTDIR/with_dlto/function_summary.txt"
} >"$SUMMARY"

echo "Results: $OUTDIR"
echo "Summary: $SUMMARY"
