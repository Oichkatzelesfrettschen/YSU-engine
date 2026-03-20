
// INT32 atomic histogram (contention characterization)
extern "C" __global__ void __launch_bounds__(256)
int32_atomic_hist(int *hist, const int *in, int n, int n_bins) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int bin=in[i]%n_bins;
    if(bin<0)bin+=n_bins;
    atomicAdd(&hist[bin],1);
}
