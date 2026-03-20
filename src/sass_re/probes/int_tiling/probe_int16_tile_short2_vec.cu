
// INT16 vectorized via short2 (32-bit load = 2 shorts)
extern "C" __global__ void __launch_bounds__(128)
int16_short2(int *out, const short2 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    short2 v=in[i];
    out[i]=(int)v.x+(int)v.y;
}
