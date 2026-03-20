
// Bit deinterleave (inverse Morton code)
extern "C" __global__ void __launch_bounds__(128)
brev_deinterleave(unsigned short *x, unsigned short *y, const unsigned *morton, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=morton[i];
    unsigned xx=v&0x55555555, yy=(v>>1)&0x55555555;
    xx=(xx|(xx>>1))&0x33333333; xx=(xx|(xx>>2))&0x0F0F0F0F;
    xx=(xx|(xx>>4))&0x00FF00FF; xx=(xx|(xx>>8))&0x0000FFFF;
    yy=(yy|(yy>>1))&0x33333333; yy=(yy|(yy>>2))&0x0F0F0F0F;
    yy=(yy|(yy>>4))&0x00FF00FF; yy=(yy|(yy>>8))&0x0000FFFF;
    x[i]=(unsigned short)xx; y[i]=(unsigned short)yy;
}
