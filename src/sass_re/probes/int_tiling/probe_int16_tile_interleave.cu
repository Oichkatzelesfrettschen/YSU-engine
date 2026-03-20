
// INT16 channel interleave (RGB interleave pattern)
extern "C" __global__ void __launch_bounds__(128)
int16_interleave(short *out, const short *r, const short *g, const short *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i*3]=r[i]; out[i*3+1]=g[i]; out[i*3+2]=b[i];
}
