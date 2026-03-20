
// Clamp to [-limit, limit] via abs+min
extern "C" __global__ void __launch_bounds__(128)
iabs_clamp(int *out, const int *in, int n, int limit) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int v=in[i];
    int sign=(v<0)?-1:1;
    int av=abs(v);
    out[i]=sign*min(av,limit);
}
