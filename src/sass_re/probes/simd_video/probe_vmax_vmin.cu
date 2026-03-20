
// SIMD packed min/max (INT16x2 and INT8x4)
extern "C" __global__ void __launch_bounds__(128)
simd_vmaxs2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vmaxs2(a[i],b[i]); // Signed INT16x2 max
}
extern "C" __global__ void __launch_bounds__(128)
simd_vmins2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vmins2(a[i],b[i]);
}
extern "C" __global__ void __launch_bounds__(128)
simd_vmaxs4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vmaxs4(a[i],b[i]); // Signed INT8x4 max
}
extern "C" __global__ void __launch_bounds__(128)
simd_vmins4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vmins4(a[i],b[i]);
}
extern "C" __global__ void __launch_bounds__(128)
simd_vmaxu2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vmaxu2(a[i],b[i]); // Unsigned INT16x2 max
}
extern "C" __global__ void __launch_bounds__(128)
simd_vminu4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vminu4(a[i],b[i]); // Unsigned INT8x4 min
}
