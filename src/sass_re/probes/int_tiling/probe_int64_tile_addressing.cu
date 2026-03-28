
// INT64 address computation (large array indexing)
extern "C" __global__ void __launch_bounds__(128)
int64_addressing(float *out, const float *in, long long stride, long long offset, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    long long addr=(long long)i*stride+offset;
    out[i]=in[addr%n];
}
