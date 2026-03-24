#!/bin/sh
# Build, run, profile, and mine the deeper OptiX + cuDNN tranche.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER_DIR="$ROOT/runners"
RESULT_ROOT="${1:-$ROOT/results/runs/tranche_ml_optix_$(date +%Y%m%d_%H%M%S)}"

NVCC="${NVCC:-nvcc}"
NCU="${NCU:-ncu}"
ARCH="${ARCH:-sm_89}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
GENERAL_METRICS="smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum"
GENERAL_NCU_OPTS="--metrics $GENERAL_METRICS --csv --target-processes all"
FULL_NCU_OPTS="--set full --csv --target-processes all"

mkdir -p "$RESULT_ROOT"/optix_callable "$RESULT_ROOT"/cudnn

echo "=== ML + OptiX Tranche Validation ==="
echo "Output: $RESULT_ROOT"
echo "Arch:   $ARCH"
echo ""

echo "=== OptiX callable/continuation pipeline ==="
sh "$SCRIPT_DIR/build_optix_callable_pipeline.sh" \
    "$RESULT_ROOT/optix_callable/optix_callable_pipeline_module.ptx" \
    "$RESULT_ROOT/optix_callable/optix_callable_pipeline_runner" \
    > "$RESULT_ROOT/optix_callable/build.log" 2>&1
"$RESULT_ROOT/optix_callable/optix_callable_pipeline_runner" \
    "$RESULT_ROOT/optix_callable/optix_callable_pipeline_module.ptx" \
    > "$RESULT_ROOT/optix_callable/run.log" 2>&1
$NCU $FULL_NCU_OPTS \
    "$RESULT_ROOT/optix_callable/optix_callable_pipeline_runner" \
    "$RESULT_ROOT/optix_callable/optix_callable_pipeline_module.ptx" \
    > "$RESULT_ROOT/optix_callable/ncu.csv" \
    2> "$RESULT_ROOT/optix_callable/ncu.log"

echo "=== cuDNN convolution runtime ==="
$NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo \
    -o "$RESULT_ROOT/cudnn/cudnn_conv_mining_runner" \
    "$RUNNER_DIR/cudnn_conv_mining_runner.cu" \
    -lcudnn -lcudnn_cnn -lcudnn_ops \
    > "$RESULT_ROOT/cudnn/build.log" 2>&1
"$RESULT_ROOT/cudnn/cudnn_conv_mining_runner" > "$RESULT_ROOT/cudnn/run.log" 2>&1
$NCU $GENERAL_NCU_OPTS "$RESULT_ROOT/cudnn/cudnn_conv_mining_runner" \
    > "$RESULT_ROOT/cudnn/ncu.csv" 2> "$RESULT_ROOT/cudnn/ncu.log"

echo "=== cuDNN library mnemonic mining ==="
sh "$SCRIPT_DIR/mine_cudnn_library_mnemonics.sh" \
    "$RESULT_ROOT/cudnn/library_mining" \
    > "$RESULT_ROOT/cudnn/library_mining_path.txt" 2>&1

cat > "$RESULT_ROOT/summary.txt" <<EOF
ML + OptiX tranche validation complete.

optix_callable:
  runtime: optix_callable/run.log
  ncu:     optix_callable/ncu.csv

cudnn:
  runtime:     cudnn/run.log
  ncu:         cudnn/ncu.csv
  library:     cudnn/library_mining/combined_mnemonics.txt
  novel:       cudnn/library_mining/novel_vs_checked_in.txt
EOF

echo ""
echo "Done: $RESULT_ROOT"
