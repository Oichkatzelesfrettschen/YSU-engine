
// INT16 conversion chain: short -> float -> compute -> float -> short
extern "C" __global__ void __launch_bounds__(128)
int16_convert(short *out, const short *in, float scale, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float v=(float)in[i]*scale;
    v=v*0.9f+0.05f;
    out[i]=(short)max(-32768.0f,min(32767.0f,v/scale));
}
