
// Q8.8 fixed-point multiply tiled
extern "C" __global__ void __launch_bounds__(128)
int16_fxp_mul(short *out, const short *a, const short *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=(short)(((int)a[i]*(int)b[i])>>8);
}
