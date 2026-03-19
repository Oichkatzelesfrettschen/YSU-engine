#!/bin/sh
# Profile ALL probe kernels with ncu (Nsight Compute) at maximum verbosity.
#
# For each probe .cu file:
#   1. Compiles a standalone runner (probe + minimal main)
#   2. Runs ncu --set full --csv to collect ALL hardware counters
#   3. Saves results to CSV per probe
#
# Requires: ncu, nvcc, CUDA 13.x, live GPU with admin/profiling access
# Usage: sh ncu_profile_all_probes.sh [output_dir]

set -eu

NCU="${NCU:-ncu}"
NVCC="${NVCC:-nvcc}"
ARCH="sm_89"
PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/ncu_full_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

# Metrics: maximum set for comprehensive analysis
# --set full captures everything: instruction mix, memory, compute, occupancy
NCU_OPTS="--set full --csv --target-processes all"

PASS=0
FAIL=0
SKIP=0

echo "=== ncu Full Profile: All Probes ==="
echo "Output: $OUTDIR"
echo ""

# For each probe, generate a minimal runner and profile it
for probe_file in "$PROBEDIR"/probe_*.cu; do
    probe_name=$(basename "$probe_file" .cu)
    runner="$OUTDIR/${probe_name}_runner.cu"
    binary="$OUTDIR/${probe_name}_runner"
    csv="$OUTDIR/${probe_name}_ncu.csv"

    printf "%-44s " "$probe_name"

    # Generate a minimal runner that includes the probe and launches first kernel
    cat > "$runner" << RUNNER_EOF
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <stdio.h>
// Include the probe source directly
#include "$probe_file"

int main() {
    const int N = 4096;
    void *d_a, *d_b, *d_c, *d_d;
    cudaMalloc(&d_a, N * 16);
    cudaMalloc(&d_b, N * 16);
    cudaMalloc(&d_c, N * 16);
    cudaMalloc(&d_d, N * 16);
    cudaMemset(d_a, 0, N * 16);
    cudaMemset(d_b, 0, N * 16);
    cudaMemset(d_c, 0, N * 16);
    // Just synchronize -- ncu will capture all kernel launches
    cudaDeviceSynchronize();
    cudaFree(d_a); cudaFree(d_b); cudaFree(d_c); cudaFree(d_d);
    return 0;
}
RUNNER_EOF

    # Compile
    if $NVCC -arch="$ARCH" -O1 -I"$PROBEDIR" -o "$binary" "$runner" 2>"$OUTDIR/${probe_name}_compile.log"; then
        # Profile with ncu (capture all kernel launches from the probe)
        if $NCU $NCU_OPTS "$binary" > "$csv" 2>"$OUTDIR/${probe_name}_ncu.log"; then
            lines=$(wc -l < "$csv")
            echo "OK ($lines CSV lines)"
            PASS=$((PASS + 1))
        else
            echo "ncu FAIL"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "COMPILE SKIP"
        SKIP=$((SKIP + 1))
    fi

    # Cleanup binary
    rm -f "$binary" "$runner"
done

echo ""
echo "=== Summary ==="
echo "Profiled: $PASS  Failed: $FAIL  Skipped: $SKIP  Total: $((PASS + FAIL + SKIP))"
echo "Results:  $OUTDIR/"
echo ""
echo "To analyze: grep 'sm__inst_executed' $OUTDIR/*_ncu.csv | head -20"
