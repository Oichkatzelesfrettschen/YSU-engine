
// INT8 -> FP32 dequantization
extern "C" __global__ void __launch_bounds__(128)
int8_dequantize(float *out, const signed char *in, float inv_scale, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=(float)in[i]*inv_scale;
}
