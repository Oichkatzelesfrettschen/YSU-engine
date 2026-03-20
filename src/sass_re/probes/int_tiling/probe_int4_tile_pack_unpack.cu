
// INT4 tiled nibble pack/unpack with latency chain
extern "C" __global__ void __launch_bounds__(128)
int4_tile_pack_chain(unsigned char *out, const float *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i*2+1 >= n) return;
    float a = in[i*2], b = in[i*2+1];
    int qa = max(-8, min(7, (int)(a*14.0f)));
    int qb = max(-8, min(7, (int)(b*14.0f)));
    out[i] = (unsigned char)(((qb&0xF)<<4)|(qa&0xF));
}
extern "C" __global__ void __launch_bounds__(128)
int4_tile_unpack_chain(float *out, const unsigned char *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    unsigned char b = in[i];
    int lo = b & 0xF; if (lo>=8) lo-=16;
    int hi = (b>>4)&0xF; if (hi>=8) hi-=16;
    out[i*2] = (float)lo/14.0f;
    out[i*2+1] = (float)hi/14.0f;
}
