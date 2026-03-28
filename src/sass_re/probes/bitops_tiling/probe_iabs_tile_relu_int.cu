
// Integer ReLU: max(0, x) = (x + abs(x)) / 2
extern "C" __global__ void __launch_bounds__(128)
iabs_relu(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int v=in[i];
    out[i]=(v+abs(v))>>1; // Branchless ReLU via abs
}
