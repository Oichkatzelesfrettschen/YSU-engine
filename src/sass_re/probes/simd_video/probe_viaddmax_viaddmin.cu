
// Intentional: these kernels use scalar max/min patterns (not inline PTX
// video mnemonics) to test whether nvcc maps them to SASS video
// instructions (VIMNMX / VIMAX3 / VIMIN3).  It does not -- the compiler
// emits plain IMNMX instead.  That negative result is the finding.
//
// The SASS video-ISA variants (VIMAX3, VIMIN3, etc.) are only reachable
// through CUDA intrinsics such as __vimax3_s32_relu (CUDA 12+).  PTX has
// no vimax3.s32 mnemonic, so inline asm is not an option either.

// SIMD max/min of 3 values (Ampere+ video instruction)
extern "C" __global__ void __launch_bounds__(128)
simd_vimax3(int *out, const int *a, const int *b, const int *c, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // Scalar max(a, max(b, c)) -- emits IMNMX, not a video op (see note above)
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
