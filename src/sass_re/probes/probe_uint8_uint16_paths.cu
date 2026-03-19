/*
 * SASS RE Probe: UINT8/UINT16 Load-Store and Conversion Paths
 * Isolates: LDG.E.U8 vs LDG.E.S8, LDG.E.U16 vs LDG.E.S16 (signed vs unsigned)
 *
 * Ada distinguishes signed and unsigned sub-32-bit loads:
 *   LDG.E.U8  -- zero-extend byte to 32-bit register
 *   LDG.E.S8  -- sign-extend byte to 32-bit register
 *   LDG.E.U16 -- zero-extend short to 32-bit register
 *   (LDG.E.S16 may or may not exist as distinct instruction)
 *
 * This probe compares all unsigned/signed load variants.
 */

// UINT8: unsigned byte load and store
extern "C" __global__ void __launch_bounds__(128)
probe_uint8_load_store(unsigned char *out, const unsigned char *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    unsigned char val = in[i];  // LDG.E.U8
    out[i] = val + 1;           // STG.E.U8
}

// INT8: signed byte load (sign-extend)
extern "C" __global__ void __launch_bounds__(128)
probe_int8_load_store(signed char *out, const signed char *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    signed char val = in[i];    // LDG.E.S8 (sign-extend)
    out[i] = val + 1;
}

// UINT16: unsigned short load
extern "C" __global__ void __launch_bounds__(128)
probe_uint16_load_store(unsigned short *out, const unsigned short *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    unsigned short val = in[i]; // LDG.E.U16
    out[i] = val + 1;           // STG.E.U16
}

// INT16: signed short load (sign-extend)
extern "C" __global__ void __launch_bounds__(128)
probe_int16_load_store(short *out, const short *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    short val = in[i];          // LDG.E.S16? or LDG.E.U16 + sign-extend?
    out[i] = val + 1;
}

// Vectorized unsigned: uchar4 (4 x UINT8 = 32 bits)
extern "C" __global__ void __launch_bounds__(128)
probe_uint8x4_load(unsigned int *out, const uchar4 *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    uchar4 v = in[i];  // LDG.E (32-bit: 4 packed bytes)
    out[i] = (unsigned)v.x + (unsigned)v.y + (unsigned)v.z + (unsigned)v.w;
}

// Vectorized unsigned: ushort4 (4 x UINT16 = 64 bits)
extern "C" __global__ void __launch_bounds__(128)
probe_uint16x4_load(unsigned int *out, const ushort4 *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    ushort4 v = in[i];  // LDG.E.64 (64-bit: 4 packed ushorts)
    out[i] = (unsigned)v.x + (unsigned)v.y + (unsigned)v.z + (unsigned)v.w;
}

// Compare: convert unsigned byte to float vs signed byte to float
extern "C" __global__ void __launch_bounds__(128)
probe_u8_vs_s8_to_float(float *out_u, float *out_s,
                         const unsigned char *u_in,
                         const signed char *s_in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    out_u[i] = (float)u_in[i];  // I2F.U8 path
    out_s[i] = (float)s_in[i];  // I2F.S8 path
}
