#!/bin/sh
# Compile all probes with maximum flags, disassemble, extract stats to CSV,
# then run ncu on latency benchmarks.
#
# Flags: -arch=sm_89 -O3 -Xptxas -O3,-warn-double-usage,-warn-spills
#        --use_fast_math --extra-device-vectorization --restrict
#        --default-stream per-thread -std=c++20 -lineinfo
#
# Output: CSV with per-kernel stats + disassembled SASS + ncu metrics

set -eu

PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
BENCHDIR="$(cd "$(dirname "$0")/../microbench" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/full_profile_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTDIR"

FLAGS="-arch=sm_89 -O3 -Xptxas -O3,-warn-double-usage,-warn-spills --use_fast_math --extra-device-vectorization --restrict --default-stream per-thread -std=c++20 -lineinfo"

echo "=== Full Compile + Profile Pipeline ===" | tee "$OUTDIR/pipeline.log"
echo "Flags: $FLAGS" | tee -a "$OUTDIR/pipeline.log"
echo "Output: $OUTDIR" | tee -a "$OUTDIR/pipeline.log"
echo "" | tee -a "$OUTDIR/pipeline.log"

# CSV header
CSV="$OUTDIR/probe_stats.csv"
echo "probe,compiled,sass_lines,unique_mnemonics,max_registers,spill_stores,spill_loads,new_mnemonics" > "$CSV"

# Baseline mnemonics (from previous sweep)
BASELINE="$OUTDIR/baseline_mnemonics.txt"

# Phase 1: Compile + disassemble all probes
echo "=== Phase 1: Compile + Disassemble ===" | tee -a "$OUTDIR/pipeline.log"
PASS=0 FAIL=0
ALL_MNEMONICS=""

for f in "$PROBEDIR"/probe_*.cu; do
    name=$(basename "$f" .cu)
    [ "$name" = "probe_optix_host_pipeline" ] && continue

    cubin="$OUTDIR/${name}.cubin"
    sass="$OUTDIR/${name}.sass"
    reglog="$OUTDIR/${name}.reg"

    if nvcc $FLAGS -Xptxas -v -cubin "$f" -o "$cubin" 2>"$reglog"; then
        cuobjdump -sass "$cubin" > "$sass" 2>/dev/null
        lines=$(grep -c '^\s\+/\*[0-9a-f]' "$sass" 2>/dev/null || echo 0)
        unique=$(grep -oP '^\s+/\*[0-9a-f]+\*/\s+\K[A-Z][A-Z0-9_.]+' "$sass" 2>/dev/null | sort -u | wc -l)
        regs=$(grep -oP 'Used \K[0-9]+(?= registers)' "$reglog" | sort -n | tail -1)
        spill_st=$(grep -oP '\K[0-9]+(?= bytes spill stores)' "$reglog" | sort -n | tail -1)
        spill_ld=$(grep -oP '\K[0-9]+(?= bytes spill loads)' "$reglog" | sort -n | tail -1)
        [ -z "$regs" ] && regs=0
        [ -z "$spill_st" ] && spill_st=0
        [ -z "$spill_ld" ] && spill_ld=0

        echo "$name,1,$lines,$unique,$regs,$spill_st,$spill_ld," >> "$CSV"
        PASS=$((PASS+1))
    else
        echo "$name,0,0,0,0,0,0,COMPILE_FAIL" >> "$CSV"
        FAIL=$((FAIL+1))
    fi
done

echo "Compiled: $PASS  Failed: $FAIL" | tee -a "$OUTDIR/pipeline.log"

# Extract combined mnemonics
for f in "$OUTDIR"/*.sass; do
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
    if nvcc $FLAGS -I"$PROBEDIR" -o "$bin" "$src" 2>"$OUTDIR/${bench}_compile.log"; then
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
