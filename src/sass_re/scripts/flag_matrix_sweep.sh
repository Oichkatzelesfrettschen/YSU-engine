#!/bin/sh
# Comprehensive compilation flag matrix sweep.
# Compiles all probes with every flag combination, captures:
#   - Register counts and spills (via -Xptxas -v)
#   - New SASS mnemonics (via cuobjdump -sass)
#   - Compilation success/failure
#
# Base flags: -arch=sm_89 -std=c++23 -lineinfo
# Usage: sh flag_matrix_sweep.sh [output_dir]

set -eu

PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/flag_sweep_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTDIR"

# Baseline mnemonic set
BASELINE="$OUTDIR/baseline_mnemonics.txt"
BASE_FLAGS="-arch=sm_89 -std=c++20 -lineinfo"

echo "=== Flag Matrix Sweep ===" | tee "$OUTDIR/sweep.log"
echo "Base: $BASE_FLAGS" | tee -a "$OUTDIR/sweep.log"
echo "Output: $OUTDIR" | tee -a "$OUTDIR/sweep.log"
echo "" | tee -a "$OUTDIR/sweep.log"

# Compile one flag set, return stats
compile_set() {
    local label="$1"
    shift
    local extra_flags="$*"
    local dir="$OUTDIR/$label"
    mkdir -p "$dir"

    local pass=0 fail=0 total_regs=0 total_spills=0 max_regs=0
    local spill_kernels=""

    for f in "$PROBEDIR"/probe_*.cu; do
        name=$(basename "$f" .cu)
        [ "$name" = "probe_optix_host_pipeline" ] && continue

        regfile="$dir/${name}.reg"
        if nvcc $BASE_FLAGS $extra_flags -Xptxas -v -cubin "$f" -o "$dir/${name}.cubin" 2>"$regfile"; then
            pass=$((pass + 1))
            # Extract register and spill info
            regs=$(grep -oP 'Used \K[0-9]+(?= registers)' "$regfile" | sort -n | tail -1)
            spills=$(grep -oP '\K[0-9]+(?= bytes spill stores)' "$regfile" | sort -n | tail -1)
            [ -z "$regs" ] && regs=0
            [ -z "$spills" ] && spills=0
            [ "$regs" -gt "$max_regs" ] && max_regs="$regs"
            total_regs=$((total_regs + regs))
            total_spills=$((total_spills + spills))
            if [ "$spills" -gt 0 ]; then
                spill_kernels="$spill_kernels $name($spills)"
            fi
        else
            fail=$((fail + 1))
        fi
    done

    # Extract mnemonics
    local mnem_file="$dir/mnemonics.txt"
    for f in "$dir"/*.cubin; do
        [ -f "$f" ] && cuobjdump -sass "$f" 2>/dev/null
    done | grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' | sort -u > "$mnem_file" 2>/dev/null

    local count=$(wc -l < "$mnem_file" 2>/dev/null || echo 0)
    local new_count=0 new_list=""
    if [ -f "$BASELINE" ]; then
        new_count=$(comm -23 "$mnem_file" "$BASELINE" 2>/dev/null | wc -l)
        new_list=$(comm -23 "$mnem_file" "$BASELINE" 2>/dev/null | tr '\n' ' ')
    fi

    printf "%-32s pass=%d fail=%d mnem=%d new=%d maxreg=%d spills=%d\n" \
        "$label" "$pass" "$fail" "$count" "$new_count" "$max_regs" "$total_spills" | tee -a "$OUTDIR/sweep.log"
    if [ -n "$spill_kernels" ]; then
        echo "  SPILLS:$spill_kernels" | tee -a "$OUTDIR/sweep.log"
    fi
    if [ "$new_count" -gt 0 ]; then
        echo "  NEW: $new_list" | tee -a "$OUTDIR/sweep.log"
    fi
}

# Build baseline
echo "Building baseline..." | tee -a "$OUTDIR/sweep.log"
compile_set "baseline" ""
cp "$OUTDIR/baseline/mnemonics.txt" "$BASELINE" 2>/dev/null

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Optimization levels ===" | tee -a "$OUTDIR/sweep.log"
compile_set "O1" "-O1"
compile_set "O2" "-O2"
compile_set "O3" "-O3"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Precision/math flags ===" | tee -a "$OUTDIR/sweep.log"
compile_set "fmad_false" "-O2 -fmad=false"
compile_set "prec_div" "-O2 --prec-div=true"
compile_set "prec_sqrt" "-O2 --prec-sqrt=true"
compile_set "ftz_false" "-O2 -ftz=false"
compile_set "fast_math" "-O2 --use_fast_math"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Register pressure ===" | tee -a "$OUTDIR/sweep.log"
compile_set "maxreg32" "-O2 --maxrregcount=32"
compile_set "maxreg64" "-O2 --maxrregcount=64"
compile_set "maxreg128" "-O2 --maxrregcount=128"
compile_set "maxreg255" "-O2 --maxrregcount=255"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Debug and special ===" | tee -a "$OUTDIR/sweep.log"
compile_set "debug_G" "-O0 -G"
compile_set "restrict" "-O2 --restrict"
compile_set "per_thread_stream" "-O2 --default-stream per-thread"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Combined ===" | tee -a "$OUTDIR/sweep.log"
compile_set "O3_prec" "-O3 --prec-div=true --prec-sqrt=true -ftz=false -fmad=false"
compile_set "O3_fast_restrict" "-O3 --use_fast_math --restrict"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== PTX warnings ===" | tee -a "$OUTDIR/sweep.log"
compile_set "warn_spills" "-O2 -Xptxas -warn-spills,-warn-lmem-usage"
compile_set "warn_double" "-O2 -Xptxas -warn-double-usage"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== SWEEP COMPLETE ===" | tee -a "$OUTDIR/sweep.log"
echo "Results in: $OUTDIR" | tee -a "$OUTDIR/sweep.log"
echo "Full log: $OUTDIR/sweep.log" | tee -a "$OUTDIR/sweep.log"
