#!/bin/sh
# Stream-extract unique SASS mnemonics from installed cuDNN libraries and diff
# them against the checked-in mnemonic census.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTDIR="${1:-$ROOT/results/runs/cudnn_mining_$(date +%Y%m%d_%H%M%S)}"
CUOBJDUMP="${CUOBJDUMP:-cuobjdump}"
KNOWN_CSV="${KNOWN_CSV:-$ROOT/results/mnemonic_census.csv}"
KEEP_SASS="${KEEP_SASS:-0}"
CUDNN_MINING_ARCH="${CUDNN_MINING_ARCH:-sm_86}"
CUDNN_MINING_PROFILE="${CUDNN_MINING_PROFILE:-core}"

mkdir -p "$OUTDIR"

extract_mnemonics() {
    python3 -c '
import re
import sys
pat = re.compile(r"^\s*/\*[0-9a-f]+\*/\s+([A-Z][A-Z0-9_.]+)")
seen = set()
for line in sys.stdin:
    m = pat.match(line)
    if m:
        seen.add(m.group(1))
for item in sorted(seen):
    print(item)
'
}

case "$CUDNN_MINING_PROFILE" in
    core)
        CANDIDATES="
/usr/lib/libcudnn_cnn.so*
/usr/lib/libcudnn_engines_runtime_compiled.so*
/usr/lib/libcudnn_engines_precompiled.so*
"
        ;;
    all)
        CANDIDATES="
/usr/lib/libcudnn_cnn.so*
/usr/lib/libcudnn_ops.so*
/usr/lib/libcudnn_adv.so*
/usr/lib/libcudnn_graph.so*
/usr/lib/libcudnn_engines_runtime_compiled.so*
/usr/lib/libcudnn_engines_precompiled.so*
"
        ;;
    *)
        echo "unsupported CUDNN_MINING_PROFILE=$CUDNN_MINING_PROFILE" >&2
        exit 2
        ;;
esac

LIBS=""
for path in $CANDIDATES; do
    if [ -f "$path" ]; then
        resolved="$(realpath "$path" 2>/dev/null || printf '%s' "$path")"
        case " $LIBS " in
            *" $resolved "*) ;;
            *) LIBS="$LIBS $resolved" ;;
        esac
    fi
done

if [ -z "$LIBS" ]; then
    echo "no cuDNN libraries found under /usr/lib" >&2
    exit 1
fi

printf "library,status,mnemonics\n" > "$OUTDIR/status.csv"
combined_tmp="$OUTDIR/combined.tmp"
: > "$combined_tmp"

for lib in $LIBS; do
    base="$(basename "$lib")"
    out="$OUTDIR/$base.mnemonics.txt"
    log="$OUTDIR/$base.cuobjdump.log"
    sass="$OUTDIR/$base.sass"
    if [ "$KEEP_SASS" = "1" ]; then
        if $CUOBJDUMP -arch "$CUDNN_MINING_ARCH" -sass "$lib" > "$sass" 2> "$log"; then
            extract_mnemonics < "$sass" > "$out"
            count="$(wc -l < "$out" | tr -d ' ')"
            printf "%s,OK,%s\n" "$base" "$count" >> "$OUTDIR/status.csv"
            cat "$out" >> "$combined_tmp"
        else
            printf "%s,FAIL,0\n" "$base" >> "$OUTDIR/status.csv"
        fi
    else
        if $CUOBJDUMP -arch "$CUDNN_MINING_ARCH" -sass "$lib" 2> "$log" | extract_mnemonics > "$out"; then
            count="$(wc -l < "$out" | tr -d ' ')"
            printf "%s,OK,%s\n" "$base" "$count" >> "$OUTDIR/status.csv"
            cat "$out" >> "$combined_tmp"
        else
            printf "%s,FAIL,0\n" "$base" >> "$OUTDIR/status.csv"
        fi
    fi
done

sort -u "$combined_tmp" > "$OUTDIR/combined_mnemonics.txt"
python3 "$SCRIPT_DIR/mnemonic_hunt.py" \
    --known "$KNOWN_CSV" \
    "$OUTDIR/combined_mnemonics.txt" \
    > "$OUTDIR/novel_vs_checked_in.txt"
rm -f "$combined_tmp"

{
    echo "cuDNN library mining complete."
    echo "arch=$CUDNN_MINING_ARCH"
    echo "profile=$CUDNN_MINING_PROFILE"
    echo "results=$OUTDIR"
    echo "combined_mnemonics=$OUTDIR/combined_mnemonics.txt"
    echo "novel_vs_checked_in=$OUTDIR/novel_vs_checked_in.txt"
} > "$OUTDIR/summary.txt"

echo "$OUTDIR"
