
// POPC via ballot: count threads meeting condition
extern "C" __global__ void __launch_bounds__(128)
popc_ballot(int *out, const float *in, float thresh, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int pred=(i<n)?(in[i]>thresh):0;
    unsigned mask=__ballot_sync(0xFFFFFFFF, pred);
    if((threadIdx.x&31)==0) atomicAdd(out,__popc(mask));
}
