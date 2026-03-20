
// INT8 tiled stencil using dp4a for neighbor accumulation
extern "C" __global__ void __launch_bounds__(128)
int8_dp4a_stencil(signed char *out, const signed char *in, int nx, int ny) {
    __shared__ signed char s[18][18];
    int tx=threadIdx.x%16, ty=threadIdx.x/16, bx=blockIdx.x*16, by=blockIdx.y*16;
    int gx=bx+tx, gy=by+ty;
    if(gx<nx&&gy<ny) s[ty+1][tx+1]=in[gy*nx+gx];
    if(tx==0&&gx>0) s[ty+1][0]=in[gy*nx+gx-1];
    if(tx==15&&gx+1<nx) s[ty+1][17]=in[gy*nx+gx+1];
    if(ty==0&&gy>0) s[0][tx+1]=in[(gy-1)*nx+gx];
    if(ty==15&&gy+1<ny) s[17][tx+1]=in[(gy+1)*nx+gx];
    __syncthreads();
    if(gx>0&&gx<nx-1&&gy>0&&gy<ny-1){
        int sum=(int)s[ty+1][tx+1]+(int)s[ty][tx+1]+(int)s[ty+2][tx+1]+(int)s[ty+1][tx]+(int)s[ty+1][tx+2];
        out[gy*nx+gx]=(signed char)(sum/5);
    }
}
