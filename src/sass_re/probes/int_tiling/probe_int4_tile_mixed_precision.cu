
// INT4 -> FP32 promotion, compute, INT4 requantize (storage-compute split)
extern "C" __global__ void __launch_bounds__(128)
int4_tile_mixed(unsigned char *out, const unsigned char *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned char b=in[i];
    int lo=b&0xF; if(lo>=8)lo-=16;
    int hi=(b>>4)&0xF; if(hi>=8)hi-=16;
    float flo=(float)lo/14.0f, fhi=(float)hi/14.0f;
    // FP32 compute
    flo=flo*0.9f+0.05f; fhi=fhi*0.9f+0.05f;
    // Requantize
    int qlo=max(-8,min(7,(int)(flo*14.0f)));
    int qhi=max(-8,min(7,(int)(fhi*14.0f)));
    out[i]=(unsigned char)(((qhi&0xF)<<4)|(qlo&0xF));
}
