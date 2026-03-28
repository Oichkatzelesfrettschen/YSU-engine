
// Bit reflection: reverse bottom N bits (for Galois fields)
extern "C" __global__ void __launch_bounds__(128)
brev_reflect(unsigned *out, const unsigned *in, int n, int bits) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i];
    unsigned rev=__brev(v)>>(32-bits);
    out[i]=rev;
}
