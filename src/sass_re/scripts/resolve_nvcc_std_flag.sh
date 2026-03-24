#!/bin/sh
# Resolve the highest C++ language mode accepted by the local nvcc.
# Prefer C++23 when supported, otherwise fall back to C++20.

set -eu

NVCC_BIN="${1:-${NVCC:-nvcc}}"
ARCH="${NVCC_STD_ARCH:-sm_89}"
TMPDIR="$(mktemp -d)"
SRC="$TMPDIR/std_probe.cu"
OBJ="$TMPDIR/std_probe.o"

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT HUP INT TERM

cat > "$SRC" <<'EOF'
__global__ void sass_re_std_probe_kernel(void) {}
EOF

probe_flag() {
    flag="$1"
    "$NVCC_BIN" -arch="$ARCH" "$flag" -c "$SRC" -o "$OBJ" >/dev/null 2>&1
}

if probe_flag "-std=c++23"; then
    printf '%s\n' "-std=c++23"
    exit 0
fi

if probe_flag "-std=c++20"; then
    printf '%s\n' "-std=c++20"
    exit 0
fi

echo "resolve_nvcc_std_flag.sh: nvcc accepts neither -std=c++23 nor -std=c++20" >&2
exit 1
