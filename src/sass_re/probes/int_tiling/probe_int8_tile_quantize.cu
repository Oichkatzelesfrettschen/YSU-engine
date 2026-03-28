
// FP32 -> INT8 quantization with scale (ML inference pattern)
extern "C" __global__ void __launch_bounds__(128)
int8_quantize(signed char *out, const float *in, float scale, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float v=in[i]*scale;
    int q=(int)roundf(v);
    q=max(-128,min(127,q));
    out[i]=(signed char)q;
}
