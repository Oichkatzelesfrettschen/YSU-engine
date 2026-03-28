
// Vectorized CLZ: 4 words per thread
extern "C" __global__ void __launch_bounds__(128)
clz_vec4(int4 *out, const uint4 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    uint4 v=in[i];
    out[i]=make_int4(__clz(v.x),__clz(v.y),__clz(v.z),__clz(v.w));
}
