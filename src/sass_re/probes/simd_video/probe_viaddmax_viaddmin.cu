
// SIMD max/min of 3 values (Ampere+ video instruction)
extern "C" __global__ void __launch_bounds__(128)
simd_vimax3(int *out, const int *a, const int *b, const int *c, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // __vimax3_s32: max(a, max(b, c)) in hardware (if supported)
    out[i] = max(a[i], max(b[i], c[i]));
}
extern "C" __global__ void __launch_bounds__(128)
simd_vimin3(int *out, const int *a, const int *b, const int *c, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i] = min(a[i], min(b[i], c[i]));
}
extern "C" __global__ void __launch_bounds__(128)
simd_vimax3_u(unsigned *out, const unsigned *a, const unsigned *b, const unsigned *c, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i] = max(a[i], max(b[i], c[i]));
}
extern "C" __global__ void __launch_bounds__(128)
simd_vimedian3(int *out, const int *a, const int *b, const int *c, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // Median of 3: max(min(a,b), min(max(a,b),c))
    int mn=min(a[i],b[i]), mx=max(a[i],b[i]);
    out[i]=max(mn,min(mx,c[i]));
}
