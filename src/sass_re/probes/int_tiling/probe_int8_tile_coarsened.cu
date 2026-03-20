
// INT8 coarsened: 4 elements per thread via int load
extern "C" __global__ void __launch_bounds__(128)
int8_coarsened(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int v=in[i]; // 4 packed INT8
    // Absolute value of each byte (uses PRMT/SHF/LOP3 chains)
    int b0=abs((v<<24)>>24), b1=abs((v<<16)>>24);
    int b2=abs((v<<8)>>24), b3=abs(v>>24);
    out[i]=(b0&0xFF)|((b1&0xFF)<<8)|((b2&0xFF)<<16)|((b3&0xFF)<<24);
}
