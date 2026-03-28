
// Normalize: shift left until MSB is set (floating-point normalization pattern)
extern "C" __global__ void __launch_bounds__(128)
clz_normalize(unsigned *out, int *shift, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i];
    int lz=__clz(v);
    out[i]=(lz<32)?(v<<lz):0;
    shift[i]=lz;
}
