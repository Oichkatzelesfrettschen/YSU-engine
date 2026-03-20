
// 64-bit population count
extern "C" __global__ void __launch_bounds__(128)
int64_popc(int *out, const unsigned long long *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned long long v=in[i];
    out[i]=__popc((unsigned)(v&0xFFFFFFFF))+__popc((unsigned)(v>>32));
}
