#!/bin/sh
# Compile and disassemble ALL probe kernels (original 9 + 7 new expanded probes)
# for Ada Lovelace SM 8.9.
#
# Outputs: one .cubin and one .sass file per probe in $OUTDIR.
# Usage: sh disassemble_expanded.sh [output_dir]

set -eu

ARCH="sm_89"
NVCC="${NVCC:-nvcc}"
CUOBJDUMP="${CUOBJDUMP:-cuobjdump}"
PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/expanded_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

PROBES="
probe_fp32_arith
probe_int_arith
probe_mufu
probe_bitwise
probe_memory
probe_conversions
probe_control_flow
probe_special_regs
probe_tensor
probe_fp16_half2
probe_fp8_precision
probe_int8_dp4a
probe_tensor_extended
probe_cache_policy
probe_nibble_packing
probe_warp_reduction
probe_bf16_arithmetic
"

PASS=0
FAIL=0

for probe in $PROBES; do
    src="$PROBEDIR/${probe}.cu"
    if [ ! -f "$src" ]; then
        echo "SKIP: $src (not found)"
        continue
    fi
    cubin="$OUTDIR/${probe}.cubin"
    sass="$OUTDIR/${probe}.sass"
    reg="$OUTDIR/${probe}.reg"

    printf "%-32s " "$probe"

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
done

echo ""
echo "Results in: $OUTDIR"
echo "Passed: $PASS  Failed: $FAIL  Total: $((PASS + FAIL))"
