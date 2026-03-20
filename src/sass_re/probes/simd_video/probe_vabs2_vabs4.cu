
// SIMD packed absolute value
extern "C" __global__ void __launch_bounds__(128)
simd_vabs2(unsigned *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vabsdiffs2(in[i],0); // |a-0| = |a|
}
extern "C" __global__ void __launch_bounds__(128)
simd_vabs4(unsigned *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=__vabsdiffs4(in[i],0);
}
