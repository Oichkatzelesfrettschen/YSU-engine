
// Bit interleave (Morton code Z-order) using BREV + BFI
extern "C" __global__ void __launch_bounds__(128)
brev_interleave(unsigned *out, const unsigned short *x, const unsigned short *y, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned xx=(unsigned)x[i], yy=(unsigned)y[i];
    // Spread bits: insert zeros between each bit
    xx=(xx|(xx<<8))&0x00FF00FF; xx=(xx|(xx<<4))&0x0F0F0F0F;
    xx=(xx|(xx<<2))&0x33333333; xx=(xx|(xx<<1))&0x55555555;
    yy=(yy|(yy<<8))&0x00FF00FF; yy=(yy|(yy<<4))&0x0F0F0F0F;
    yy=(yy|(yy<<2))&0x33333333; yy=(yy|(yy<<1))&0x55555555;
    out[i]=xx|(yy<<1); // Morton code
}
