
// INT16 clamp to range
extern "C" __global__ void __launch_bounds__(128)
int16_clamp(short *out, const short *in, short lo, short hi, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    short v=in[i];
    out[i]=max(lo,min(hi,v));
}
