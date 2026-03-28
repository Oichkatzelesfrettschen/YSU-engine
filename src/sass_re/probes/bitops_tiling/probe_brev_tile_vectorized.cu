
// Vectorized BREV: 4 words per thread
extern "C" __global__ void __launch_bounds__(128)
brev_vec4(uint4 *out, const uint4 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    uint4 v=in[i];
    out[i]=make_uint4(__brev(v.x),__brev(v.y),__brev(v.z),__brev(v.w));
}
