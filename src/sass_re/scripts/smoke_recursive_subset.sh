#!/bin/sh
# Smoke-test a representative recursive subset through the 6 canonical lanes,
# targeted runtime validation, and Nsight Compute.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NVCC="${NVCC:-nvcc}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
OUTDIR="${1:-$SCRIPT_DIR/../results/runs/smoke_recursive_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTDIR"/{lanes,disasm,logs,ncu}
printf 'lane,probe,status\n' > "$OUTDIR/lanes/compile_status.csv"
printf 'target,status,csv_lines\n' > "$OUTDIR/ncu/ncu_status.csv"

BASE_FLAGS="-arch=sm_89 $NVCC_STD_FLAG -lineinfo"

run_ncu() {
    label="$1"
    csv="$2"
    log="$3"
    shift 3
    if "$@" > "$csv" 2> "$log"; then
        lines=$(wc -l < "$csv" | tr -d ' ')
        printf '%s,OK,%s\n' "$label" "$lines" >> "$OUTDIR/ncu/ncu_status.csv"
    else
        rc=$?
        printf '%s,FAIL_%s,0\n' "$label" "$rc" >> "$OUTDIR/ncu/ncu_status.csv"
        : > "$csv"
    fi
}

for label in O2 O2_xptxas_O3 O3 O3_xptxas_O3 G G_xptxas_O3; do
    case "$label" in
        O2) flags="-O2" ;;
        O2_xptxas_O3) flags="-O2 -Xptxas -O3" ;;
        O3) flags="-O3" ;;
        O3_xptxas_O3) flags="-O3 -Xptxas -O3" ;;
        G) flags="-O0 -G" ;;
        G_xptxas_O3) flags="-O0 -G -Xptxas -O3" ;;
    esac
    mkdir -p "$OUTDIR/lanes/$label"
    for rel in \
        probe_fp32_arith.cu \
        atomic_sweep/probe_redux_all_ops.cu \
        barrier_sync2/probe_bar_red_predicate.cu \
        atomic_sweep/probe_dp4a_signedness.cu \
        data_movement/probe_cp_async_zfill.cu \
        texture_surface/probe_tmu_behavior.cu
    do
        src="$SCRIPT_DIR/../probes/$rel"
        base=${rel%.cu}
        cubin="$OUTDIR/lanes/$label/$base.cubin"
        sass="$OUTDIR/lanes/$label/$base.sass"
        reg="$OUTDIR/lanes/$label/$base.reg"
        mkdir -p "$(dirname "$cubin")"
        if $NVCC $BASE_FLAGS $flags -Xptxas -v -cubin "$src" -o "$cubin" 2>"$reg"; then
            cuobjdump -sass "$cubin" > "$sass"
            printf '%s,%s,OK\n' "$label" "$rel" >> "$OUTDIR/lanes/compile_status.csv"
        else
            printf '%s,%s,COMPILE_FAIL\n' "$label" "$rel" >> "$OUTDIR/lanes/compile_status.csv"
        fi
    done
    find "$OUTDIR/lanes/$label" -type f -name '*.sass' | while IFS= read -r sass_file; do
        grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' "$sass_file" 2>/dev/null || true
    done | sort -u > "$OUTDIR/lanes/$label/mnemonics.txt"
done

python3 "$SCRIPT_DIR/mnemonic_hunt.py" \
    "$OUTDIR/lanes/O2/mnemonics.txt" \
    "$OUTDIR/lanes/O2_xptxas_O3/mnemonics.txt" \
    "$OUTDIR/lanes/O3/mnemonics.txt" \
    "$OUTDIR/lanes/O3_xptxas_O3/mnemonics.txt" \
    "$OUTDIR/lanes/G/mnemonics.txt" \
    "$OUTDIR/lanes/G_xptxas_O3/mnemonics.txt" \
    > "$OUTDIR/lanes/novel_vs_checked_in.txt"

$NVCC -arch=sm_89 $NVCC_STD_FLAG "$SCRIPT_DIR/../runners/dp4a_signedness_runner.cu" -o "$OUTDIR/logs/dp4a_runner"
"$OUTDIR/logs/dp4a_runner" > "$OUTDIR/logs/dp4a_runner.txt" 2>&1
$NVCC -arch=sm_89 $NVCC_STD_FLAG "$SCRIPT_DIR/../runners/cp_async_zfill_runner.cu" -o "$OUTDIR/logs/cp_async_runner"
"$OUTDIR/logs/cp_async_runner" > "$OUTDIR/logs/cp_async_runner.txt" 2>&1
$NVCC -arch=sm_89 $NVCC_STD_FLAG "$SCRIPT_DIR/../runners/texture_surface_runner.cu" -o "$OUTDIR/logs/texture_runner"
"$OUTDIR/logs/texture_runner" probe_tmu_behavior > "$OUTDIR/logs/texture_tmu_behavior.txt" 2>&1

python3 "$SCRIPT_DIR/probe_manifest.py" generate-runner --probe atomic_sweep/probe_redux_all_ops.cu --output "$OUTDIR/ncu/redux_runner.cu"
$NVCC -arch=sm_89 $NVCC_STD_FLAG "$OUTDIR/ncu/redux_runner.cu" -o "$OUTDIR/ncu/redux_runner"
python3 "$SCRIPT_DIR/probe_manifest.py" generate-runner --probe barrier_sync2/probe_bar_red_predicate.cu --output "$OUTDIR/ncu/bar_red_runner.cu"
$NVCC -arch=sm_89 $NVCC_STD_FLAG "$OUTDIR/ncu/bar_red_runner.cu" -o "$OUTDIR/ncu/bar_red_runner"

run_ncu dp4a "$OUTDIR/ncu/dp4a.csv" "$OUTDIR/ncu/dp4a.log" \
    ncu --metrics smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum --csv --target-processes all \
    "$OUTDIR/logs/dp4a_runner"
run_ncu cp_async "$OUTDIR/ncu/cp_async.csv" "$OUTDIR/ncu/cp_async.log" \
    ncu --metrics smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum --csv --target-processes all \
    "$OUTDIR/logs/cp_async_runner" --profile-safe
run_ncu redux "$OUTDIR/ncu/redux.csv" "$OUTDIR/ncu/redux.log" \
    ncu --metrics smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum --csv --target-processes all \
    "$OUTDIR/ncu/redux_runner"
run_ncu bar_red "$OUTDIR/ncu/bar_red.csv" "$OUTDIR/ncu/bar_red.log" \
    ncu --metrics smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum --csv --target-processes all \
    "$OUTDIR/ncu/bar_red_runner"
run_ncu texture_tmu_behavior_full "$OUTDIR/ncu/texture_tmu_behavior_full.csv" "$OUTDIR/ncu/texture_tmu_behavior_full.log" \
    ncu --set full --csv --target-processes all \
    "$OUTDIR/logs/texture_runner" probe_tmu_behavior

printf 'Smoke artifacts: %s\n' "$OUTDIR"
