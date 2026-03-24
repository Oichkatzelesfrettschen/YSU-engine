#!/bin/sh
# Comprehensive recursive compilation flag matrix sweep.
# Compiles every recursive probe with each flag lane, captures:
#   - Register counts and spills (via -Xptxas -v)
#   - Raw emitted SASS mnemonics (via cuobjdump -sass)
#   - Compilation success/failure, including diagnostic lanes
#
# Usage: sh flag_matrix_sweep.sh [output_dir]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NVCC="${NVCC:-nvcc}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
MANIFEST_PY="$SCRIPT_DIR/probe_manifest.py"
OUTDIR="${1:-$SCRIPT_DIR/../results/runs/flag_sweep_$(date +%Y%m%d_%H%M%S)}"
SWEEP_JOBS="${FLAG_SWEEP_JOBS:-6}"
SWEEP_EXTRACT_JOBS="${FLAG_SWEEP_EXTRACT_JOBS:-4}"
mkdir -p "$OUTDIR"

# Baseline mnemonic set
BASELINE="$OUTDIR/baseline_mnemonics.txt"
BASE_FLAGS="-arch=sm_89 $NVCC_STD_FLAG -lineinfo"
MANIFEST_TSV="$OUTDIR/probe_manifest.tsv"
CHECKED_IN_BASELINE="$OUTDIR/checked_in_mnemonics.txt"
python3 "$MANIFEST_PY" emit --format tsv > "$MANIFEST_TSV"
awk -F, 'NR>1 {print $2}' "$SCRIPT_DIR/../results/mnemonic_census.csv" | sort -u > "$CHECKED_IN_BASELINE"

echo "=== Flag Matrix Sweep ===" | tee "$OUTDIR/sweep.log"
echo "Base: $BASE_FLAGS" | tee -a "$OUTDIR/sweep.log"
echo "Output: $OUTDIR" | tee -a "$OUTDIR/sweep.log"
echo "Compile jobs: $SWEEP_JOBS" | tee -a "$OUTDIR/sweep.log"
echo "Extract jobs: $SWEEP_EXTRACT_JOBS" | tee -a "$OUTDIR/sweep.log"
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
    local pid_list=""
    local active=0

    while IFS="$(printf '\t')" read -r probe_id rel_path basename compile_enabled runner_kind supports_generic_runner kernel_names skip_reason; do
        [ "$compile_enabled" = "1" ] || continue
        src="$SCRIPT_DIR/../probes/$rel_path"
        rel_base=${rel_path%.cu}
        cubin="$dir/$rel_base.cubin"
        regfile="$dir/$rel_base.reg"
        statusfile="$dir/$rel_base.status"
        mkdir -p "$(dirname "$cubin")"
        (
            if $NVCC $BASE_FLAGS $extra_flags -Xptxas -v -cubin "$src" -o "$cubin" 2>"$regfile"; then
                echo ok > "$statusfile"
            else
                echo fail > "$statusfile"
            fi
        ) &
        pid=$!
        pid_list="${pid_list}${pid} "
        active=$((active + 1))
        if [ "$active" -ge "$SWEEP_JOBS" ]; then
            first_pid=${pid_list%% *}
            wait "$first_pid" || true
            pid_list=${pid_list#"$first_pid" }
            active=$((active - 1))
        fi
    done < "$MANIFEST_TSV"

    for pid in $pid_list; do
        wait "$pid" || true
    done

    while IFS="$(printf '\t')" read -r probe_id rel_path basename compile_enabled runner_kind supports_generic_runner kernel_names skip_reason; do
        [ "$compile_enabled" = "1" ] || continue
        rel_base=${rel_path%.cu}
        regfile="$dir/$rel_base.reg"
        statusfile="$dir/$rel_base.status"
        status=fail
        if [ -f "$statusfile" ]; then
            status=$(cat "$statusfile")
        fi
        if [ "$status" = "ok" ]; then
            pass=$((pass + 1))
            regs=$(grep -oP 'Used \K[0-9]+(?= registers)' "$regfile" | sort -n | tail -1)
            spills=$(grep -oP '\K[0-9]+(?= bytes spill stores)' "$regfile" | sort -n | tail -1)
            [ -z "$regs" ] && regs=0
            [ -z "$spills" ] && spills=0
            [ "$regs" -gt "$max_regs" ] && max_regs="$regs"
            total_regs=$((total_regs + regs))
            total_spills=$((total_spills + spills))
            if [ "$spills" -gt 0 ]; then
                spill_kernels="$spill_kernels ${probe_id}($spills)"
            fi
        else
            fail=$((fail + 1))
        fi
    done < "$MANIFEST_TSV"

    local mnem_file="$dir/mnemonics.txt"
    local extract_tmp="$dir/.extract"
    local cubin_list="$dir/.extract_cubins.txt"
    mkdir -p "$extract_tmp"
    pid_list=""
    active=0
    find "$dir" -type f -name '*.cubin' > "$cubin_list"
    while IFS= read -r f; do
        rel_name=${f#"$dir"/}
        out_tmp="$extract_tmp/$(printf '%s' "$rel_name" | tr '/' '_').sass.txt"
        (
            cuobjdump -sass "$f" 2>/dev/null || true
        ) > "$out_tmp" &
        pid=$!
        pid_list="${pid_list}${pid} "
        active=$((active + 1))
        if [ "$active" -ge "$SWEEP_EXTRACT_JOBS" ]; then
            first_pid=${pid_list%% *}
            wait "$first_pid" || true
            pid_list=${pid_list#"$first_pid" }
            active=$((active - 1))
        fi
    done < "$cubin_list"
    for pid in $pid_list; do
        wait "$pid" || true
    done
    find "$extract_tmp" -type f -name '*.sass.txt' | while IFS= read -r f; do
        cat "$f"
    done | grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' | sort -u > "$mnem_file" 2>/dev/null
    rm -rf "$extract_tmp"
    rm -f "$cubin_list"

    local count=$(wc -l < "$mnem_file" 2>/dev/null || echo 0)
    local new_count=0 new_list=""
    local checked_in_new_count=0 checked_in_new_list=""
    if [ -f "$BASELINE" ]; then
        new_count=$(comm -23 "$mnem_file" "$BASELINE" 2>/dev/null | wc -l)
        new_list=$(comm -23 "$mnem_file" "$BASELINE" 2>/dev/null | tr '\n' ' ')
    fi
    if [ -f "$CHECKED_IN_BASELINE" ]; then
        checked_in_new_count=$(comm -23 "$mnem_file" "$CHECKED_IN_BASELINE" 2>/dev/null | wc -l)
        checked_in_new_list=$(comm -23 "$mnem_file" "$CHECKED_IN_BASELINE" 2>/dev/null | tr '\n' ' ')
        comm -23 "$mnem_file" "$CHECKED_IN_BASELINE" 2>/dev/null > "$dir/novel_vs_checked_in.txt" || true
    fi

    printf "%-32s pass=%d fail=%d mnem=%d new=%d maxreg=%d spills=%d\n" \
        "$label" "$pass" "$fail" "$count" "$new_count" "$max_regs" "$total_spills" | tee -a "$OUTDIR/sweep.log"
    if [ -n "$spill_kernels" ]; then
        echo "  SPILLS:$spill_kernels" | tee -a "$OUTDIR/sweep.log"
    fi
    if [ "$new_count" -gt 0 ]; then
        echo "  NEW: $new_list" | tee -a "$OUTDIR/sweep.log"
    fi
    if [ "$checked_in_new_count" -gt 0 ]; then
        echo "  NOVEL_VS_CHECKED_IN: $checked_in_new_list" | tee -a "$OUTDIR/sweep.log"
    fi
}

# Build baseline
echo "Building baseline..." | tee -a "$OUTDIR/sweep.log"
compile_set "baseline" ""
cp "$OUTDIR/baseline/mnemonics.txt" "$BASELINE" 2>/dev/null

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Canonical Matrix ===" | tee -a "$OUTDIR/sweep.log"
compile_set "O2" "-O2"
compile_set "O2_xptxas_O3" "-O2 -Xptxas -O3"
compile_set "O3" "-O3"
compile_set "O3_xptxas_O3" "-O3 -Xptxas -O3"
compile_set "G" "-O0 -G"
compile_set "G_xptxas_O3" "-O0 -G -Xptxas -O3"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: Precision/Math ===" | tee -a "$OUTDIR/sweep.log"
compile_set "fmad_false" "-O2 -fmad=false"
compile_set "prec_div" "-O2 --prec-div=true"
compile_set "prec_sqrt" "-O2 --prec-sqrt=true"
compile_set "ftz_false" "-O2 -ftz=false"
compile_set "fast_math" "-O2 --use_fast_math"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: Register Pressure ===" | tee -a "$OUTDIR/sweep.log"
compile_set "maxreg32" "-O2 --maxrregcount=32"
compile_set "maxreg64" "-O2 --maxrregcount=64"
compile_set "maxreg128" "-O2 --maxrregcount=128"
compile_set "maxreg255" "-O2 --maxrregcount=255"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: Special Flags ===" | tee -a "$OUTDIR/sweep.log"
compile_set "restrict" "-O2 --restrict"
compile_set "per_thread_stream" "-O2 --default-stream per-thread"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: Verified Toolchain Knobs ===" | tee -a "$OUTDIR/sweep.log"
compile_set "G_dopt_on" "-O0 -G -dopt=on"
compile_set "vec" "-O2 --extra-device-vectorization"
compile_set "vec_restrict" "-O2 --extra-device-vectorization --restrict"
compile_set "fast_vec_restrict" "-O3 --use_fast_math --extra-device-vectorization --restrict"
compile_set "dlcm_cg" "-O2 -Xptxas -dlcm=cg"
compile_set "disable_opt_consts" "-O2 -Xptxas -disable-optimizer-consts"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: Combined ===" | tee -a "$OUTDIR/sweep.log"
compile_set "O3_prec" "-O3 --prec-div=true --prec-sqrt=true -ftz=false -fmad=false"
compile_set "O3_fast_restrict" "-O3 --use_fast_math --restrict"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== Discovery Delta: PTX Warnings ===" | tee -a "$OUTDIR/sweep.log"
compile_set "warn_spills" "-O2 -Xptxas -warn-spills,-warn-lmem-usage"
compile_set "warn_double" "-O2 -Xptxas -warn-double-usage"

echo "" | tee -a "$OUTDIR/sweep.log"
echo "=== SWEEP COMPLETE ===" | tee -a "$OUTDIR/sweep.log"
echo "Results in: $OUTDIR" | tee -a "$OUTDIR/sweep.log"
echo "Full log: $OUTDIR/sweep.log" | tee -a "$OUTDIR/sweep.log"
