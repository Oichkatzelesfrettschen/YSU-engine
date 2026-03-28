
// INT8 max pooling (2x2)
extern "C" __global__ void __launch_bounds__(128)
int8_max_pool(signed char *out, const signed char *in, int nx, int ny) {
    int ox=threadIdx.x+blockIdx.x*blockDim.x;
    int oy=blockIdx.y;
    if(ox>=nx/2||oy>=ny/2)return;
    int ix=ox*2, iy=oy*2;
    signed char a=in[iy*nx+ix], b=in[iy*nx+ix+1];
    signed char c=in[(iy+1)*nx+ix], d=in[(iy+1)*nx+ix+1];
    signed char m=max(max(a,b),max(c,d));
    out[oy*(nx/2)+ox]=m;
}
