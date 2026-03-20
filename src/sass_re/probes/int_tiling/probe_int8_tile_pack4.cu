
// INT8 vectorized: load 4 bytes as int, process, store
extern "C" __global__ void __launch_bounds__(128)
int8_pack4(int *out, const int *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int packed=in[i]; // 4 INT8 values packed in 1 int
    // Extract, process, repack (uses SHF/BFE/BFI)
    int b0=(packed<<24)>>24, b1=(packed<<16)>>24, b2=(packed<<8)>>24, b3=packed>>24;
    b0=abs(b0); b1=abs(b1); b2=abs(b2); b3=abs(b3);
    out[i]=(b0&0xFF)|((b1&0xFF)<<8)|((b2&0xFF)<<16)|((b3&0xFF)<<24);
}
