
// INT4 element-wise comparison (generates ISETP on nibbles)
extern "C" __global__ void __launch_bounds__(128)
int4_tile_cmp(unsigned char *out, const unsigned char *a, const unsigned char *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int a_lo=a[i]&0xF, b_lo=b[i]&0xF;
    if(a_lo>=8)a_lo-=16; if(b_lo>=8)b_lo-=16;
    int a_hi=(a[i]>>4)&0xF, b_hi=(b[i]>>4)&0xF;
    if(a_hi>=8)a_hi-=16; if(b_hi>=8)b_hi-=16;
    int r_lo=(a_lo>b_lo)?a_lo:b_lo; // max
    int r_hi=(a_hi>b_hi)?a_hi:b_hi;
    out[i]=(unsigned char)(((r_hi&0xF)<<4)|(r_lo&0xF));
}
