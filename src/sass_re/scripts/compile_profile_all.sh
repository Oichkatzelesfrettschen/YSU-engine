#!/bin/sh
# Compile the recursive probe corpus with a high-signal profiling lane,
# disassemble every successful build, and extract per-probe stats.
#
# Output:
#   - mirrored .cubin/.sass/.reg artifacts
#   - per-probe CSV rows keyed by probe_id and relative path
#   - combined mnemonic inventory

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NVCC="${NVCC:-nvcc}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
BENCHDIR="$(cd "$SCRIPT_DIR/../microbench" && pwd)"
PROBEDIR="$(cd "$SCRIPT_DIR/../probes" && pwd)"
MANIFEST_PY="$SCRIPT_DIR/probe_manifest.py"
OUTDIR="${1:-$SCRIPT_DIR/../results/runs/full_profile_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTDIR"

FLAGS="-arch=sm_89 -O3 -Xptxas -O3,-warn-double-usage,-warn-spills --use_fast_math --extra-device-vectorization --restrict --default-stream per-thread $NVCC_STD_FLAG -lineinfo"
MANIFEST_TSV="$OUTDIR/probe_manifest.tsv"
python3 "$MANIFEST_PY" emit --format tsv > "$MANIFEST_TSV"

echo "=== Full Compile + Profile Pipeline ===" | tee "$OUTDIR/pipeline.log"
echo "Flags: $FLAGS" | tee -a "$OUTDIR/pipeline.log"
echo "Output: $OUTDIR" | tee -a "$OUTDIR/pipeline.log"
echo "" | tee -a "$OUTDIR/pipeline.log"

# CSV header
CSV="$OUTDIR/probe_stats.csv"
echo "probe_id,relative_path,compiled,sass_lines,unique_mnemonics,max_registers,spill_stores,spill_loads,status" > "$CSV"

# Phase 1: Compile + disassemble all probes
echo "=== Phase 1: Compile + Disassemble ===" | tee -a "$OUTDIR/pipeline.log"
PASS=0 FAIL=0
ALL_MNEMONICS=""

while IFS="$(printf '\t')" read -r probe_id rel_path basename compile_enabled runner_kind supports_generic_runner kernel_names skip_reason; do
    [ "$compile_enabled" = "1" ] || continue
    src="$SCRIPT_DIR/../probes/$rel_path"
    rel_base=${rel_path%.cu}
    cubin="$OUTDIR/$rel_base.cubin"
    sass="$OUTDIR/$rel_base.sass"
    reglog="$OUTDIR/$rel_base.reg"
    mkdir -p "$(dirname "$cubin")"

    if $NVCC $FLAGS -Xptxas -v -cubin "$src" -o "$cubin" 2>"$reglog"; then
        cuobjdump -sass "$cubin" > "$sass" 2>/dev/null
        lines=$(grep -c '^\s\+/\*[0-9a-f]' "$sass" 2>/dev/null || echo 0)
        unique=$(grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' "$sass" 2>/dev/null | sort -u | wc -l)
        regs=$(grep -oP 'Used \K[0-9]+(?= registers)' "$reglog" | sort -n | tail -1)
        spill_st=$(grep -oP '\K[0-9]+(?= bytes spill stores)' "$reglog" | sort -n | tail -1)
        spill_ld=$(grep -oP '\K[0-9]+(?= bytes spill loads)' "$reglog" | sort -n | tail -1)
        [ -z "$regs" ] && regs=0
        [ -z "$spill_st" ] && spill_st=0
        [ -z "$spill_ld" ] && spill_ld=0

        echo "$probe_id,$rel_path,1,$lines,$unique,$regs,$spill_st,$spill_ld,OK" >> "$CSV"
        PASS=$((PASS+1))
    else
        echo "$probe_id,$rel_path,0,0,0,0,0,0,COMPILE_FAIL" >> "$CSV"
        FAIL=$((FAIL+1))
    fi
done < "$MANIFEST_TSV"

echo "Compiled: $PASS  Failed: $FAIL" | tee -a "$OUTDIR/pipeline.log"

# Extract combined mnemonics
find "$OUTDIR" -type f -name '*.sass' | while IFS= read -r f; do
    grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' "$f" 2>/dev/null
done | sort -u > "$OUTDIR/all_mnemonics.txt"
TOTAL_MNEM=$(wc -l < "$OUTDIR/all_mnemonics.txt")
echo "Total unique mnemonics: $TOTAL_MNEM" | tee -a "$OUTDIR/pipeline.log"

# Phase 2: Compile and run latency benchmarks
echo "" | tee -a "$OUTDIR/pipeline.log"
echo "=== Phase 2: Latency Benchmarks ===" | tee -a "$OUTDIR/pipeline.log"

BENCH_CSV="$OUTDIR/benchmark_results.csv"
echo "benchmark,instruction,latency_cy,flags" > "$BENCH_CSV"

for bench in microbench_latency microbench_latency_expanded microbench_latency_wave5 microbench_latency_corrected microbench_latency_conversions microbench_latency_tensor_all microbench_remaining_latencies microbench_fill_all_na; do
    src="$BENCHDIR/${bench}.cu"
    [ ! -f "$src" ] && continue
    bin="$OUTDIR/${bench}"

    echo "  Building $bench..." | tee -a "$OUTDIR/pipeline.log"
    if $NVCC $FLAGS -I"$PROBEDIR" -o "$bin" "$src" 2>"$OUTDIR/${bench}_compile.log"; then
        echo "  Running $bench..." | tee -a "$OUTDIR/pipeline.log"
        "$bin" > "$OUTDIR/${bench}_output.txt" 2>&1 || true
        # Extract latency lines to CSV
        grep -oP '^\S.*\s+\K[0-9]+\.[0-9]+$' "$OUTDIR/${bench}_output.txt" 2>/dev/null | while read lat; do
            echo "$bench,,$lat,$FLAGS" >> "$BENCH_CSV"
        done
    else
        echo "  COMPILE FAIL: $bench" | tee -a "$OUTDIR/pipeline.log"
    fi
done

echo "" | tee -a "$OUTDIR/pipeline.log"
echo "=== Pipeline Complete ===" | tee -a "$OUTDIR/pipeline.log"
echo "Probe stats: $CSV" | tee -a "$OUTDIR/pipeline.log"
echo "Benchmark results: $BENCH_CSV" | tee -a "$OUTDIR/pipeline.log"
echo "Mnemonics: $OUTDIR/all_mnemonics.txt ($TOTAL_MNEM unique)" | tee -a "$OUTDIR/pipeline.log"
