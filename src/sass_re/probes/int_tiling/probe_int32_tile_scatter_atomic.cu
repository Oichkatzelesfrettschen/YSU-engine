
// INT32 scatter with atomic (histogram-like, different contention)
extern "C" __global__ void __launch_bounds__(128)
int32_scatter_atomic(int *out, const int *vals, const int *indices, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    atomicAdd(&out[indices[i]],vals[i]);
}
