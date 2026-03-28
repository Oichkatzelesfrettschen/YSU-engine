
// INT32 tiled 3D 7-point stencil
extern "C" __global__ void __launch_bounds__(256)
int32_stencil3d(int *out, const int *in, int nx, int ny, int nz) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=nx*ny*nz)return;
    int x=i%nx, y=(i/nx)%ny, z=i/(nx*ny);
    int c=in[i], sum=c*6;
    if(x>0) sum-=in[i-1]; if(x<nx-1) sum-=in[i+1];
    if(y>0) sum-=in[i-nx]; if(y<ny-1) sum-=in[i+nx];
    if(z>0) sum-=in[i-nx*ny]; if(z<nz-1) sum-=in[i+nx*ny];
    out[i]=sum;
}
