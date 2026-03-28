
// Sparse bit counting: skip zero words
extern "C" __global__ void __launch_bounds__(128)
popc_sparse(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned w=in[i];
    out[i]=(w!=0)?__popc(w):0;
}
