#!/bin/sh
# Profile the recursive probe corpus with Nsight Compute.
#
# Plain probes use a targeted metric set to avoid replay explosion.
# Texture/surface probes use a dedicated host runner and --set full.
#
# Usage: sh ncu_profile_all_probes.sh [output_dir]

set -eu

NCU="${NCU:-ncu}"
NVCC="${NVCC:-nvcc}"
ARCH="sm_89"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NVCC_STD_FLAG="$("$SCRIPT_DIR/resolve_nvcc_std_flag.sh" "$NVCC")"
MANIFEST_PY="$SCRIPT_DIR/probe_manifest.py"
RUNNER_DIR="$SCRIPT_DIR/../runners"
OUTDIR="${1:-$SCRIPT_DIR/../results/runs/ncu_full_$(date +%Y%m%d_%H%M%S)}"
KEEP_RUNNER_ARTIFACTS="${KEEP_RUNNER_ARTIFACTS:-0}"

mkdir -p "$OUTDIR"

GENERAL_METRICS="smsp__inst_executed.sum,smsp__warp_active.avg,l1tex__t_bytes.sum,dram__bytes.sum"
GENERAL_OPTS="--metrics $GENERAL_METRICS --csv --target-processes all"
TMU_OPTS="--set full --csv --target-processes all"
MANIFEST_TSV="$OUTDIR/probe_manifest.tsv"
python3 "$MANIFEST_PY" emit --format tsv > "$MANIFEST_TSV"

printf "metric,status\n" > "$OUTDIR/metric_preflight.csv"
for metric in smsp__inst_executed.sum smsp__warp_active.avg l1tex__t_bytes.sum dram__bytes.sum; do
    if $NCU --query-metrics | grep -F "$metric" >/dev/null 2>&1; then
        echo "$metric,OK" >> "$OUTDIR/metric_preflight.csv"
    else
        echo "$metric,MISSING" >> "$OUTDIR/metric_preflight.csv"
    fi
done

PASS=0
FAIL=0
SKIP=0

echo "=== ncu Full Profile: All Probes ==="
echo "Output: $OUTDIR"
echo ""

is_expected_skip_probe() {
    case "$1" in
        probe_optix_rt_core.cu|\
        probe_uniform_ushf_u64_hi_final.cu)
            return 0
            ;;
    esac
    return 1
}

cleanup_runner_artifacts() {
    if [ "$KEEP_RUNNER_ARTIFACTS" = "1" ]; then
        return
    fi
    rm -f "$@"
}

while IFS="$(printf '\t')" read -r probe_id rel_path basename compile_enabled runner_kind supports_generic_runner kernel_names skip_reason; do
    profile_enabled=0
    case "$runner_kind" in
        texture_surface|cp_async_zfill|mbarrier|barrier_arrive_wait|barrier_coop_groups|cooperative_launch|tiling_hierarchical|depbar_explicit|optix_pipeline|optix_callable_pipeline|optical_flow|video_codec|cudnn)
            profile_enabled=1
            ;;
    esac
    if [ "$compile_enabled" != "1" ] && [ "$profile_enabled" != "1" ]; then
        continue
    fi
    probe_out="$OUTDIR/${rel_path%.cu}"
    mkdir -p "$probe_out"
    runner="$probe_out/${probe_id}_runner.cu"
    binary="$probe_out/${probe_id}_runner"
    csv="$probe_out/${probe_id}_ncu.csv"
    compile_log="$probe_out/${probe_id}_compile.log"
    ncu_log="$probe_out/${probe_id}_ncu.log"
    metadata="$probe_out/${probe_id}_metadata.txt"

    printf "%-56s " "$rel_path"

    echo "probe_id=$probe_id" > "$metadata"
    echo "relative_path=$rel_path" >> "$metadata"
    echo "runner_kind=$runner_kind" >> "$metadata"
    echo "kernel_names=$kernel_names" >> "$metadata"

    if is_expected_skip_probe "$rel_path"; then
        echo "EXPECTED SKIP"
        echo "status=EXPECTED_SKIP" >> "$metadata"
        SKIP=$((SKIP + 1))
        continue
    fi

    if [ "$runner_kind" = "texture_surface" ]; then
        binary="$probe_out/texture_surface_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/texture_surface_runner.cu" 2>"$compile_log"; then
            probe_selector=$(basename "$rel_path" .cu)
            if $NCU $TMU_OPTS "$binary" "$probe_selector" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK TMU ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "cp_async_zfill" ]; then
        binary="$probe_out/cp_async_zfill_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/cp_async_zfill_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" --profile-safe > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK cp.async ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "mbarrier" ]; then
        binary="$probe_out/mbarrier_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/mbarrier_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK mbarrier ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "barrier_arrive_wait" ]; then
        binary="$probe_out/barrier_arrive_wait_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/barrier_arrive_wait_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK barrier-arrive ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "barrier_coop_groups" ]; then
        binary="$probe_out/barrier_coop_groups_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/barrier_coop_groups_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK barrier-cg ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "tiling_hierarchical" ]; then
        binary="$probe_out/tiling_hierarchical_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/tiling_hierarchical_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK tiling-hier ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "cooperative_launch" ]; then
        binary="$probe_out/cooperative_launch_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/cooperative_launch_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK cooperative-launch ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "depbar_explicit" ]; then
        binary="$probe_out/depbar_explicit_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$RUNNER_DIR/depbar_explicit_runner.cu" 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK depbar-explicit ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "optix_pipeline" ]; then
        build_script="$SCRIPT_DIR/build_optix_real_pipeline.sh"
        ptx="$probe_out/optix_real_pipeline_device.ptx"
        binary="$probe_out/optix_real_pipeline_runner"
        if sh "$build_script" "$ptx" "$binary" >"$compile_log" 2>&1; then
            if $NCU $TMU_OPTS "$binary" "$ptx" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK OptiX ($lines CSV lines)"
                cleanup_runner_artifacts "$binary" "$ptx"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "optix_callable_pipeline" ]; then
        build_script="$SCRIPT_DIR/build_optix_callable_pipeline.sh"
        ptx="$probe_out/optix_callable_pipeline_device.ptx"
        binary="$probe_out/optix_callable_pipeline_runner"
        if sh "$build_script" "$ptx" "$binary" >"$compile_log" 2>&1; then
            if $NCU $TMU_OPTS "$binary" "$ptx" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK OptiX-callable ($lines CSV lines)"
                cleanup_runner_artifacts "$binary" "$ptx"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "optical_flow" ]; then
        binary="$probe_out/ofa_pipeline_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -I/usr/include/nvidia -I/usr/include/nvidia/opticalflow \
            -o "$binary" "$RUNNER_DIR/ofa_pipeline_runner.cu" -lcuda -lnvidia-opticalflow 2>"$compile_log"; then
            if $NCU $TMU_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK OFA ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "video_codec" ]; then
        binary="$probe_out/nvenc_nvdec_pipeline_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -I/usr/include/nvidia-sdk \
            -o "$binary" "$RUNNER_DIR/nvenc_nvdec_pipeline_runner.cu" -lcuda -lnvidia-encode -lnvcuvid 2>"$compile_log"; then
            if $NCU $TMU_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK video ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$runner_kind" = "cudnn" ]; then
        binary="$probe_out/cudnn_conv_mining_runner"
        if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo \
            -o "$binary" "$RUNNER_DIR/cudnn_conv_mining_runner.cu" \
            -lcudnn -lcudnn_cnn -lcudnn_ops 2>"$compile_log"; then
            if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
                lines=$(wc -l < "$csv")
                echo "OK cuDNN ($lines CSV lines)"
                cleanup_runner_artifacts "$binary"
                PASS=$((PASS + 1))
            else
                echo "ncu FAIL"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "COMPILE SKIP"
            SKIP=$((SKIP + 1))
        fi
        continue
    fi

    if [ "$supports_generic_runner" != "1" ]; then
        echo "UNSUPPORTED RUNNER"
        echo "status=UNSUPPORTED_RUNNER" >> "$metadata"
        SKIP=$((SKIP + 1))
        continue
    fi

    python3 "$MANIFEST_PY" generate-runner --probe "$rel_path" --output "$runner"
    if $NVCC -arch="$ARCH" -O3 $NVCC_STD_FLAG -lineinfo -o "$binary" "$runner" 2>"$compile_log"; then
        if $NCU $GENERAL_OPTS "$binary" > "$csv" 2>"$ncu_log"; then
            lines=$(wc -l < "$csv")
            echo "OK ($lines CSV lines)"
            cleanup_runner_artifacts "$runner" "$binary"
            PASS=$((PASS + 1))
        else
            echo "ncu FAIL"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "COMPILE SKIP"
        SKIP=$((SKIP + 1))
    fi
done < "$MANIFEST_TSV"

echo ""
echo "=== Summary ==="
echo "Profiled: $PASS  Failed: $FAIL  Skipped: $SKIP  Total: $((PASS + FAIL + SKIP))"
echo "Results:  $OUTDIR/"
echo ""
echo "Targeted metrics: $GENERAL_METRICS"
