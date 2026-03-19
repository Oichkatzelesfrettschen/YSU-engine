#!/bin/sh
# Profile LBM kernels with NVIDIA Nsight Systems (nsys) for timeline analysis.
#
# Captures: kernel launch timeline, GPU activity, memory transfers,
# CUDA API calls, and SM occupancy over time.
#
# Requires: nsys (NVIDIA Nsight Systems CLI) and a live CUDA GPU.
# Usage: sh profile_nsys_timeline.sh <executable> [args...]

set -eu

NSYS="${NSYS:-nsys}"
OUTDIR="${NSYS_OUTDIR:-$(dirname "$0")/../results/nsys_$(date +%Y%m%d_%H%M%S)}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <executable> [args...]"
    echo "  Profiles the given CUDA executable with nsys."
    echo "  Output goes to: $OUTDIR/"
    echo ""
    echo "Examples:"
    echo "  $0 ./build/bin/lbm_bench --grid 128 --steps 100"
    echo "  $0 ./probe_runner"
    exit 1
fi

mkdir -p "$OUTDIR"

EXE="$1"
shift

echo "Nsight Systems timeline profiling"
echo "Executable: $EXE $*"
echo "Output: $OUTDIR"
echo ""

# Trace: CUDA API, kernel launches, memory ops, OS runtime
$NSYS profile \
    --trace=cuda,nvtx,osrt \
    --cuda-memory-usage=true \
    --gpu-metrics-device=all \
    --output="$OUTDIR/timeline" \
    --force-overwrite=true \
    -- "$EXE" "$@"

echo ""
echo "Timeline captured: $OUTDIR/timeline.nsys-rep"
echo "Open with: nsys-ui $OUTDIR/timeline.nsys-rep"

# Generate summary stats
$NSYS stats "$OUTDIR/timeline.nsys-rep" \
    --report gputrace \
    --format csv \
    --output "$OUTDIR/gpu_trace" 2>/dev/null || true

echo "GPU trace summary: $OUTDIR/gpu_trace.csv"
