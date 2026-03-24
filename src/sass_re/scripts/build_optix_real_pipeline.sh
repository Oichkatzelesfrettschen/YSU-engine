#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: build_optix_real_pipeline.sh <ptx_out> <runner_out>" >&2
    exit 2
fi

PTX_OUT="$1"
RUNNER_OUT="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER_DIR="$ROOT/runners"
NVCC="${NVCC:-nvcc}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"

mkdir -p "$(dirname "$PTX_OUT")" "$(dirname "$RUNNER_OUT")"

$NVCC -arch=sm_89 $NVCC_STD_FLAG -lineinfo --ptx \
    -I/usr/include -I/usr/include/optix \
    "$RUNNER_DIR/optix_real_pipeline_device.cu" \
    -o "$PTX_OUT"

$NVCC -arch=sm_89 $NVCC_STD_FLAG -lineinfo \
    -I/usr/include -I/usr/include/optix \
    "$RUNNER_DIR/optix_real_pipeline_runner.cu" \
    -o "$RUNNER_OUT" -lcuda -ldl
