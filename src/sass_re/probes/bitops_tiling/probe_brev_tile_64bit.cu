
// 64-bit BREV via two 32-bit BREV + swap
extern "C" __global__ void __launch_bounds__(128)
brev_64bit(unsigned long long *out, const unsigned long long *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned long long v=in[i];
    unsigned lo=__brev((unsigned)(v&0xFFFFFFFFu));
    unsigned hi=__brev((unsigned)(v>>32));
    out[i]=((unsigned long long)lo<<32)|hi;
}
