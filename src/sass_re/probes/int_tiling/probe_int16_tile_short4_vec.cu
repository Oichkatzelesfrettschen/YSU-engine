
// INT16 vectorized via short4 (64-bit load = 4 shorts)
extern "C" __global__ void __launch_bounds__(128)
int16_short4(int *out, const short4 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    short4 v=in[i];
    out[i]=(int)v.x+(int)v.y+(int)v.z+(int)v.w;
}
