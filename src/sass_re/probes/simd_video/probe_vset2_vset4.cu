
// SIMD packed comparison (set)
extern "C" __global__ void __launch_bounds__(128)
simd_vsetge2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vsetges2(a[i],b[i]); // Signed INT16x2: (a>=b) ? 0xFFFF : 0
}
extern "C" __global__ void __launch_bounds__(128)
simd_vseteq4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vseteq4(a[i],b[i]); // INT8x4: (a==b) ? 0xFF : 0
}
