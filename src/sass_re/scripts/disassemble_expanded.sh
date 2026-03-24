#!/bin/sh
# Compile and disassemble the full recursive probe corpus for Ada SM 8.9.
#
# Outputs: mirrored .cubin/.sass/.reg artifacts plus a manifest snapshot.
# Usage: sh disassemble_expanded.sh [output_dir]

set -eu

ARCH="sm_89"
NVCC="${NVCC:-nvcc}"
CUOBJDUMP="${CUOBJDUMP:-cuobjdump}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST_PY="$SCRIPT_DIR/probe_manifest.py"
OUTDIR="${1:-$SCRIPT_DIR/../results/runs/expanded_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"
MANIFEST_TSV="$OUTDIR/probe_manifest.tsv"
python3 "$MANIFEST_PY" emit --format tsv > "$MANIFEST_TSV"

PASS=0
FAIL=0

while IFS="$(printf '\t')" read -r probe_id rel_path basename compile_enabled runner_kind supports_generic_runner kernel_names skip_reason; do
    if [ "$compile_enabled" != "1" ]; then
        echo "SKIP: $rel_path ($skip_reason)"
        continue
    fi
    src="$SCRIPT_DIR/../probes/$rel_path"
    rel_base=${rel_path%.cu}
    cubin="$OUTDIR/$rel_base.cubin"
    sass="$OUTDIR/$rel_base.sass"
    reg="$OUTDIR/$rel_base.reg"
    mkdir -p "$(dirname "$cubin")"

    printf "%-48s " "$rel_path"

    # Compile to cubin with register info
    if $NVCC -arch="$ARCH" -cubin "$src" -o "$cubin" 2>"$reg"; then
        # Disassemble
        $CUOBJDUMP -sass "$cubin" > "$sass" 2>/dev/null
        lines=$(wc -l < "$sass")
        regs=$(grep -o 'Used [0-9]* registers' "$reg" | tail -1 || echo "?")
        echo "OK  ($lines SASS lines, $regs)"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        cat "$reg"
        FAIL=$((FAIL + 1))
    fi
done < "$MANIFEST_TSV"

echo ""
echo "Results in: $OUTDIR"
echo "Passed: $PASS  Failed: $FAIL  Total: $((PASS + FAIL))"
