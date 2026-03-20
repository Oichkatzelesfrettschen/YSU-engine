
// INT16 tiled 5-point stencil
extern "C" __global__ void __launch_bounds__(256)
int16_stencil(short *out, const short *in, int nx, int ny) {
    __shared__ short s[18][18];
    int tx=threadIdx.x%16, ty=threadIdx.x/16, gx=blockIdx.x*16+tx, gy=blockIdx.y*16+ty;
    if(gx<nx&&gy<ny) s[ty+1][tx+1]=in[gy*nx+gx];
    if(tx==0&&gx>0) s[ty+1][0]=in[gy*nx+gx-1];
    if(tx==15&&gx+1<nx) s[ty+1][17]=in[gy*nx+gx+1];
    if(ty==0&&gy>0) s[0][tx+1]=in[(gy-1)*nx+gx];
    if(ty==15&&gy+1<ny) s[17][tx+1]=in[(gy+1)*nx+gx];
    __syncthreads();
    if(gx>0&&gx<nx-1&&gy>0&&gy<ny-1){
        int sum=(int)s[ty+1][tx+1]+(int)s[ty][tx+1]+(int)s[ty+2][tx+1]+(int)s[ty+1][tx]+(int)s[ty+1][tx+2];
        out[gy*nx+gx]=(short)(sum/5);
    }
}
