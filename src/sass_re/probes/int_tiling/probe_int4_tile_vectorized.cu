
// INT4 vectorized: load 4 bytes = 8 nibbles at once via uint32
extern "C" __global__ void __launch_bounds__(128)
int4_tile_vec4(float *out, const unsigned int *packed, int n_words) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n_words)return;
    unsigned int w=packed[i];
    float sum=0.0f;
    #pragma unroll
    for(int b=0;b<8;b++){
        int nib=(w>>(b*4))&0xF;
        if(nib>=8)nib-=16;
        sum+=(float)nib;
    }
    out[i]=sum/14.0f;
}
