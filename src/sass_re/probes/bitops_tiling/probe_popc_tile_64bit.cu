
// 64-bit POPC via two 32-bit POPC
extern "C" __global__ void __launch_bounds__(128)
popc_64bit(int *out, const unsigned long long *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned long long v=in[i];
    out[i]=__popc((unsigned)(v&0xFFFFFFFFu))+__popc((unsigned)(v>>32));
}
