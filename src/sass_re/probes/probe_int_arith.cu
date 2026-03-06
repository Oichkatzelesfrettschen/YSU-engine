/*
 * SASS RE Probe: Integer Arithmetic
 * Isolates: IADD3, IMAD, ISETP, LEA, IABS, IMNMX
 *
 * Note: Ada Lovelace uses IADD3 (3-input add) instead of IADD.
 * IMAD is integer multiply-add (the integer workhorse).
 * LEA (load effective address) is used for address calculations.
 */

// IADD3 chain -- integer add (3 inputs: Ra + Rb + Rc)
extern "C" __global__ void __launch_bounds__(32)
probe_iadd3(int *out, const int *a, const int *b, const int *c) {
    int i = threadIdx.x;
    int x = a[i];
    int y = b[i];
    int z = c[i];
    // The compiler often folds c=0, but with 3 inputs it must use IADD3
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    x = x + y + z;
    out[i] = x;
}

// IMAD chain: x = x*y + z
extern "C" __global__ void __launch_bounds__(32)
probe_imad(int *out, const int *a, const int *b, const int *c) {
    int i = threadIdx.x;
    int x = a[i];
    int y = b[i];
    int z = c[i];
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    x = x * y + z;
    out[i] = x;
}

// ISETP: integer set-predicate (compare)
extern "C" __global__ void __launch_bounds__(32)
probe_isetp(int *out, const int *a, const int *b) {
    int i = threadIdx.x;
    int x = a[i];
    int y = b[i];
    int count = 0;
    // Each comparison should generate an ISETP + predicated instruction
    if (x > y) count++;
    if (x < y) count++;
    if (x >= y) count++;
    if (x <= y) count++;
    if (x == y) count++;
    if (x != y) count++;
    // Unsigned comparisons
    if ((unsigned)x > (unsigned)y) count++;
    if ((unsigned)x < (unsigned)y) count++;
    out[i] = count;
}

// LEA: load effective address (used for pointer arithmetic)
// The compiler emits LEA for scaled index calculations
extern "C" __global__ void __launch_bounds__(32)
probe_lea(int *out, const int *base, int stride) {
    int i = threadIdx.x;
    // Accessing base[i*stride] forces LEA for address calc
    int val = 0;
    val += base[i * stride];
    val += base[i * stride + 1];
    val += base[i * stride + 2];
    val += base[i * stride + 3];
    out[i] = val;
}

// IMAD.WIDE: 32x32->64-bit multiply (used for 64-bit address calculations)
extern "C" __global__ void __launch_bounds__(32)
probe_imad_wide(long long *out, const int *a, const int *b) {
    int i = threadIdx.x;
    long long x = (long long)a[i] * (long long)b[i];
    long long y = (long long)a[i+32] * (long long)b[i+32];
    x = x + y;
    out[i] = x;
}

// IMNMX: integer min/max
extern "C" __global__ void __launch_bounds__(32)
probe_imnmx(int *out, const int *a, const int *b) {
    int i = threadIdx.x;
    int x = a[i];
    int y = b[i];
    x = min(x, y);
    x = max(x, y);
    x = min(x, y);
    x = max(x, y);
    x = min(x, y);
    x = max(x, y);
    x = min(x, y);
    x = max(x, y);
    out[i] = x;
}
