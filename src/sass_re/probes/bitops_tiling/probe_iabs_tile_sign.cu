
// Sign extraction via abs: sign(x) = x / abs(x)
extern "C" __global__ void __launch_bounds__(128)
iabs_sign(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int v=in[i];
    out[i]=(v>0)?1:((v<0)?-1:0);
}
