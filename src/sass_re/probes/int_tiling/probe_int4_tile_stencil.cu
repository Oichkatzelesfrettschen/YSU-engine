
// INT4 tiled stencil: nibble-packed 1D stencil
extern "C" __global__ void __launch_bounds__(128)
int4_tile_stencil(unsigned char *out, const unsigned char *in, int n) {
    __shared__ unsigned char s[130];
    int tid = threadIdx.x, gi = blockIdx.x*128+tid;
    if (gi<n) s[tid+1]=in[gi];
    if (tid==0 && gi>0) s[0]=in[gi-1];
    if (tid==127 && gi+1<n) s[129]=in[gi+1];
    __syncthreads();
    if (gi<n) {
        int c=(s[tid+1]&0xF); if(c>=8)c-=16;
        int l=(s[tid]&0xF);   if(l>=8)l-=16;
        int r=(s[tid+2]&0xF); if(r>=8)r-=16;
        int avg=(l+c+r)/3;
        out[gi]=(unsigned char)(avg&0xF);
    }
}
