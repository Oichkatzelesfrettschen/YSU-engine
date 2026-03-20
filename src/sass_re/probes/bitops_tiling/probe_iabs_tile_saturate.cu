
// Saturating abs (handle INT_MIN overflow: abs(INT_MIN) = INT_MAX)
extern "C" __global__ void __launch_bounds__(128)
iabs_saturate(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int v=in[i];
    out[i]=(v==0x80000000)?0x7FFFFFFF:abs(v);
}
