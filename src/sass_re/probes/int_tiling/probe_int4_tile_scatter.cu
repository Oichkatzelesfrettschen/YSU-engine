
// INT4 scatter: nibble-packed indirect write
extern "C" __global__ void __launch_bounds__(128)
int4_tile_scatter(unsigned char *out, const unsigned char *in, const int *idx, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[idx[i]]=in[i];
}
