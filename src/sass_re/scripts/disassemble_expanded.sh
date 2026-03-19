#!/bin/sh
# Compile and disassemble ALL probe kernels (original 9 + 7 new expanded probes)
# for Ada Lovelace SM 8.9.
#
# Outputs: one .cubin and one .sass file per probe in $OUTDIR.
# Usage: sh disassemble_expanded.sh [output_dir]

set -eu

ARCH="sm_89"
NVCC="${NVCC:-nvcc}"
CUOBJDUMP="${CUOBJDUMP:-cuobjdump}"
PROBEDIR="$(cd "$(dirname "$0")/../probes" && pwd)"
OUTDIR="${1:-$(dirname "$0")/../results/expanded_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

PROBES="
probe_fp32_arith
probe_int_arith
probe_mufu
probe_bitwise
probe_memory
probe_conversions
probe_control_flow
probe_special_regs
probe_tensor
probe_fp16_half2
probe_fp8_precision
probe_int8_dp4a
probe_tensor_extended
probe_cache_policy
probe_nibble_packing
probe_warp_reduction
probe_bf16_arithmetic
probe_async_copy
probe_fp64_arithmetic
probe_register_pressure
probe_mixed_precision
probe_vectorized_widths
probe_transcendentals
probe_nanosleep_scheduling
probe_predicate_pressure
probe_atomic_throughput
probe_encoding_verify
probe_fp64_extended
probe_texture_surface
probe_constant_memory
probe_uniform_datapath
probe_tensor_ldsm
probe_warp_elect_activemask
probe_bit_manipulation
probe_swizzled_add
probe_memory_scope
probe_convergence_barriers
probe_cooperative_launch
probe_4bit_formats
probe_uint4_tensor
probe_int128_uint128_emulated
probe_tf32_scalar
probe_nonexistent_formats_emulation
probe_tensor_all_widths
probe_int16_arithmetic
probe_uint8_uint16_paths
probe_fp32_special_modes
probe_fp64_transcendentals
probe_int64_arithmetic
probe_warp_matrix_shared
probe_coalescing_patterns
probe_l1_l2_dram_boundary
"

PASS=0
FAIL=0

for probe in $PROBES; do
    src="$PROBEDIR/${probe}.cu"
    if [ ! -f "$src" ]; then
        echo "SKIP: $src (not found)"
        continue
    fi
    cubin="$OUTDIR/${probe}.cubin"
    sass="$OUTDIR/${probe}.sass"
    reg="$OUTDIR/${probe}.reg"

    printf "%-32s " "$probe"

    # Compile to cubin with register info
    if $NVCC -arch="$ARCH" -cubin "$src" -o "$cubin" 2>"$reg"; then
        # Disassemble
        $CUOBJDUMP -sass "$cubin" > "$sass" 2>/dev/null
        lines=$(wc -l < "$sass")
        regs=$(grep -o 'Used [0-9]* registers' "$reg" | tail -1 || echo "?")
        echo "OK  ($lines SASS lines, $regs)"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        cat "$reg"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "Results in: $OUTDIR"
echo "Passed: $PASS  Failed: $FAIL  Total: $((PASS + FAIL))"
