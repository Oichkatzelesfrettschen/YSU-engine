
// SIMD Sum of Absolute Differences (SAD)
extern "C" __global__ void __launch_bounds__(128)
simd_vsad2(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // SAD of packed INT16x2
    unsigned diff = __vabsdiffu2(a[i],b[i]);
    out[i] = (diff & 0xFFFF) + (diff >> 16); // Sum both halves
}
extern "C" __global__ void __launch_bounds__(128)
simd_vsad4(unsigned *out, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    // SAD of packed INT8x4
    unsigned diff = __vabsdiffu4(a[i],b[i]);
    out[i] = (diff&0xFF) + ((diff>>8)&0xFF) + ((diff>>16)&0xFF) + (diff>>24);
}
