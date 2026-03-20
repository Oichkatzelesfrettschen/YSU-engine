
// INT16 absolute difference
extern "C" __global__ void __launch_bounds__(128)
int16_abs_diff(short *out, const short *a, const short *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=(short)abs((int)a[i]-(int)b[i]);
}
