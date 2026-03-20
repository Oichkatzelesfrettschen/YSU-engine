
// SIMD packed INT16x2: add and subtract
extern "C" __global__ void __launch_bounds__(128)
simd_vadd2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // __vadd2: packed INT16x2 add (2 INT16 adds in 1 instruction)
    out[i]=__vadd2(a[i],b[i]);
}
extern "C" __global__ void __launch_bounds__(128)
simd_vsub2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vsub2(a[i],b[i]);
}
