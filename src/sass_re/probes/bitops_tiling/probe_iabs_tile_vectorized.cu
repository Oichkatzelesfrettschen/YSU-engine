
// Vectorized abs: 4 ints per thread
extern "C" __global__ void __launch_bounds__(128)
iabs_vec4(int4 *out, const int4 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int4 v=in[i];
    out[i]=make_int4(abs(v.x),abs(v.y),abs(v.z),abs(v.w));
}
