
// SIMD packed INT8x4: add and subtract
extern "C" __global__ void __launch_bounds__(128)
simd_vadd4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // __vadd4: packed INT8x4 add (4 INT8 adds in 1 instruction)
    out[i]=__vadd4(a[i],b[i]);
}
extern "C" __global__ void __launch_bounds__(128)
simd_vsub4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vsub4(a[i],b[i]);
}
