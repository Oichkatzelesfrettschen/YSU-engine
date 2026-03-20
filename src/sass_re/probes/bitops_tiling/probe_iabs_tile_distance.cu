
// Manhattan distance via abs
extern "C" __global__ void __launch_bounds__(128)
iabs_manhattan(int *out, const int *ax, const int *ay, const int *bx, const int *by, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=abs(ax[i]-bx[i])+abs(ay[i]-by[i]);
}
