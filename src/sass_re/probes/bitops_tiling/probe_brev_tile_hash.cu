
// BREV as mixing function for hash
extern "C" __global__ void __launch_bounds__(128)
brev_hash(unsigned *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i];
    v=__brev(v); v^=(v>>16); v*=0x45d9f3bu;
    v=__brev(v); v^=(v>>13); v*=0xc68f8c7u;
    out[i]=v;
}
