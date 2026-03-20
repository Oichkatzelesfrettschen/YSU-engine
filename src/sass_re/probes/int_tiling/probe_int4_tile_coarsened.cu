
// INT4 coarsened: 4 bytes (16 nibbles) per thread
extern "C" __global__ void __launch_bounds__(128)
int4_tile_coarse4(float *out, const unsigned int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i*4+3>=n)return;
    unsigned int w0=in[i*4],w1=in[i*4+1],w2=in[i*4+2],w3=in[i*4+3];
    float s0=0,s1=0,s2=0,s3=0;
    for(int b=0;b<8;b++){
        int n0=(w0>>(b*4))&0xF; if(n0>=8)n0-=16; s0+=(float)n0;
        int n1=(w1>>(b*4))&0xF; if(n1>=8)n1-=16; s1+=(float)n1;
        int n2=(w2>>(b*4))&0xF; if(n2>=8)n2-=16; s2+=(float)n2;
        int n3=(w3>>(b*4))&0xF; if(n3>=8)n3-=16; s3+=(float)n3;
    }
    out[i*4]=s0; out[i*4+1]=s1; out[i*4+2]=s2; out[i*4+3]=s3;
}
