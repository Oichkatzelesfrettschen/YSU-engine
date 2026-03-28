
// All REDUX variants: SUM, MIN, MAX, AND, OR (already found XOR)
extern "C" __global__ void __launch_bounds__(128)
redux_all(int *out, const int *in, int n) {
    int gi = blockIdx.x*blockDim.x+threadIdx.x;
    int val = (gi<n) ? in[gi] : 0;
    int rsum = __reduce_add_sync(0xFFFFFFFF, val);
    int rmin = __reduce_min_sync(0xFFFFFFFF, val);
    int rmax = __reduce_max_sync(0xFFFFFFFF, val);
    unsigned uval = (unsigned)val;
    unsigned rand = __reduce_and_sync(0xFFFFFFFF, uval);
    unsigned ror  = __reduce_or_sync(0xFFFFFFFF, uval);
    if((threadIdx.x&31)==0) {
        out[blockIdx.x*5] = rsum;
        out[blockIdx.x*5+1] = rmin;
        out[blockIdx.x*5+2] = rmax;
        out[blockIdx.x*5+3] = (int)rand;
        out[blockIdx.x*5+4] = (int)ror;
    }
}
