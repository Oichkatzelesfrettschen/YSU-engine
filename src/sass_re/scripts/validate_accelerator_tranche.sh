#!/bin/sh
# Build, run, disassemble, and profile the accelerator-domain tranche:
# - mbarrier
# - OptiX real pipeline
# - Optical Flow Accelerator
# - NVENC / NVDEC
#
# Output goes into the ignored run tree under src/sass_re/results/runs/.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER_DIR="$ROOT/runners"
PROBE_DIR="$ROOT/probes"
RESULT_ROOT="${1:-$ROOT/results/runs/tranche_accel_$(date +%Y%m%d_%H%M%S)}"

NVCC="${NVCC:-nvcc}"
NCU="${NCU:-ncu}"
ARCH="${ARCH:-sm_89}"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
GENERAL_METRICS="smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum"
GENERAL_NCU_OPTS="--metrics $GENERAL_METRICS --csv --target-processes all"
FULL_NCU_OPTS="--set full --csv --target-processes all"

mkdir -p "$RESULT_ROOT"/mbarrier "$RESULT_ROOT"/optix "$RESULT_ROOT"/ofa "$RESULT_ROOT"/video

echo "=== Accelerator Tranche Validation ==="
echo "Output: $RESULT_ROOT"
echo "Arch:   $ARCH"
echo ""

echo "=== mbarrier ==="
$NVCC -arch="$ARCH" $NVCC_STD_FLAG -cubin \
    "$PROBE_DIR/mbarrier/probe_mbarrier_core.cu" \
    -o "$RESULT_ROOT/mbarrier/probe_mbarrier_core.cubin"
cuobjdump -sass "$RESULT_ROOT/mbarrier/probe_mbarrier_core.cubin" \
    > "$RESULT_ROOT/mbarrier/probe_mbarrier_core.sass"
python3 "$SCRIPT_DIR/sass_function_summary.py" \
    "$RESULT_ROOT/mbarrier/probe_mbarrier_core.sass" \
    --focus "ATOMS.ARRIVE.64,ATOMS.POPC.INC.32,BAR.SYNC.DEFER_BLOCKING,MEMBAR.ALL.CTA" \
    > "$RESULT_ROOT/mbarrier/probe_mbarrier_core.summary.txt"
$NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo \
    -o "$RESULT_ROOT/mbarrier/mbarrier_runner" \
    "$RUNNER_DIR/mbarrier_runner.cu" \
    > "$RESULT_ROOT/mbarrier/build.log" 2>&1
"$RESULT_ROOT/mbarrier/mbarrier_runner" > "$RESULT_ROOT/mbarrier/run.log" 2>&1
$NCU $GENERAL_NCU_OPTS "$RESULT_ROOT/mbarrier/mbarrier_runner" \
    > "$RESULT_ROOT/mbarrier/ncu.csv" 2> "$RESULT_ROOT/mbarrier/ncu.log"

echo "=== OptiX ==="
$NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo --ptx \
    -I/usr/include -I/usr/include/optix \
    "$RUNNER_DIR/optix_real_pipeline_device.cu" \
    -o "$RESULT_ROOT/optix/optix_real_pipeline_device.ptx" \
    > "$RESULT_ROOT/optix/device_ptx_build.log" 2>&1
if $NVCC -arch="$ARCH" $NVCC_STD_FLAG -lineinfo -cubin \
    -I/usr/include -I/usr/include/optix \
    "$RUNNER_DIR/optix_real_pipeline_device.cu" \
    -o "$RESULT_ROOT/optix/optix_real_pipeline_device.cubin" \
    > "$RESULT_ROOT/optix/device_cubin_build.log" 2>&1; then
    cuobjdump -sass "$RESULT_ROOT/optix/optix_real_pipeline_device.cubin" \
        > "$RESULT_ROOT/optix/optix_real_pipeline_device.sass"
    python3 "$SCRIPT_DIR/sass_function_summary.py" \
        "$RESULT_ROOT/optix/optix_real_pipeline_device.sass" \
        --focus "CALL.ABS.NOINC,CALL.REL.NOINC,STG.E,LDG.E,MOV" \
        > "$RESULT_ROOT/optix/optix_real_pipeline_device.summary.txt"
    echo "optix_device_cubin=1" > "$RESULT_ROOT/optix/device_status.txt"
else
    echo "optix_device_cubin=0" > "$RESULT_ROOT/optix/device_status.txt"
    echo "note=standalone cubin assembly fails because OptiX intrinsics are resolved via the OptiX module JIT path on this setup" \
        >> "$RESULT_ROOT/optix/device_status.txt"
fi
sh "$SCRIPT_DIR/build_optix_real_pipeline.sh" \
    "$RESULT_ROOT/optix/optix_real_pipeline_module.ptx" \
    "$RESULT_ROOT/optix/optix_real_pipeline_runner" \
    > "$RESULT_ROOT/optix/build.log" 2>&1
"$RESULT_ROOT/optix/optix_real_pipeline_runner" \
    "$RESULT_ROOT/optix/optix_real_pipeline_module.ptx" \
    > "$RESULT_ROOT/optix/run.log" 2>&1
$NCU $FULL_NCU_OPTS \
    "$RESULT_ROOT/optix/optix_real_pipeline_runner" \
    "$RESULT_ROOT/optix/optix_real_pipeline_module.ptx" \
    > "$RESULT_ROOT/optix/ncu.csv" 2> "$RESULT_ROOT/optix/ncu.log"

echo "=== OFA ==="
$NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo \
    -I/usr/include/nvidia -I/usr/include/nvidia/opticalflow \
    -o "$RESULT_ROOT/ofa/ofa_pipeline_runner" \
    "$RUNNER_DIR/ofa_pipeline_runner.cu" \
    -lcuda -lnvidia-opticalflow \
    > "$RESULT_ROOT/ofa/build.log" 2>&1
"$RESULT_ROOT/ofa/ofa_pipeline_runner" > "$RESULT_ROOT/ofa/run.log" 2>&1
$NCU $FULL_NCU_OPTS "$RESULT_ROOT/ofa/ofa_pipeline_runner" \
    > "$RESULT_ROOT/ofa/ncu.csv" 2> "$RESULT_ROOT/ofa/ncu.log"

echo "=== NVENC / NVDEC ==="
$NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo \
    -I/usr/include/nvidia-sdk \
    -o "$RESULT_ROOT/video/nvenc_nvdec_pipeline_runner" \
    "$RUNNER_DIR/nvenc_nvdec_pipeline_runner.cu" \
    -lcuda -lnvidia-encode -lnvcuvid \
    > "$RESULT_ROOT/video/build.log" 2>&1
"$RESULT_ROOT/video/nvenc_nvdec_pipeline_runner" > "$RESULT_ROOT/video/run.log" 2>&1
$NCU $FULL_NCU_OPTS "$RESULT_ROOT/video/nvenc_nvdec_pipeline_runner" \
    > "$RESULT_ROOT/video/ncu.csv" 2> "$RESULT_ROOT/video/ncu.log"

cat > "$RESULT_ROOT/summary.txt" <<EOF
Accelerator tranche validation complete.

mbarrier:
  disassembly: mbarrier/probe_mbarrier_core.sass
  runtime:     mbarrier/run.log
  ncu:         mbarrier/ncu.csv

optix:
  device ptx:  optix/optix_real_pipeline_device.ptx
  device info: optix/device_status.txt
  runtime:     optix/run.log
  ncu:         optix/ncu.csv

ofa:
  runtime:     ofa/run.log
  ncu:         ofa/ncu.csv

video:
  runtime:     video/run.log
  ncu:         video/ncu.csv
EOF

echo ""
echo "Done: $RESULT_ROOT"
