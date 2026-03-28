
// Vectorized POPC: 4 words per thread via uint4
extern "C" __global__ void __launch_bounds__(128)
popc_vec4(int *out, const uint4 *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    uint4 v=in[i];
    out[i]=__popc(v.x)+__popc(v.y)+__popc(v.z)+__popc(v.w);
}
