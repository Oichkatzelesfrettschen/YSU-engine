
// Absolute difference: |a-b| (SAD pattern)
extern "C" __global__ void __launch_bounds__(128)
iabs_sad(int *out, const int *a, const int *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=abs(a[i]-b[i]);
}
