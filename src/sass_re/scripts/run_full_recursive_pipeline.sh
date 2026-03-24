#!/bin/sh
# Run the full recursive Ada pipeline into a single run root.
#
# Usage:
#   sh run_full_recursive_pipeline.sh /abs/path/to/run_root

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: sh run_full_recursive_pipeline.sh /abs/path/to/run_root" >&2
    exit 2
fi

RUNROOT="$1"
LOG="$RUNROOT/full_recursive.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$RUNROOT"

printf 'RUNROOT=%s\n' "$RUNROOT" | tee "$LOG"
sh "$SCRIPT_DIR/disassemble_expanded.sh" "$RUNROOT/disassembly" 2>&1 | tee -a "$LOG"
sh "$SCRIPT_DIR/flag_matrix_sweep.sh" "$RUNROOT/lanes" 2>&1 | tee -a "$LOG"
sh "$SCRIPT_DIR/compile_profile_all.sh" "$RUNROOT/compile_profile" 2>&1 | tee -a "$LOG"
sh "$SCRIPT_DIR/ncu_profile_all_probes.sh" "$RUNROOT/ncu" 2>&1 | tee -a "$LOG"
echo FULL_RECURSIVE_DONE | tee -a "$LOG"
