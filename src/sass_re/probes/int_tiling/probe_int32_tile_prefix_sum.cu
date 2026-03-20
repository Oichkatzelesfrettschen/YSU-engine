
// INT32 block-level prefix sum (scan)
extern "C" __global__ void __launch_bounds__(256)
int32_prefix_sum(int *out, const int *in, int n) {
    __shared__ int s[256];
    int tid=threadIdx.x, gi=blockIdx.x*256+tid;
    s[tid]=(gi<n)?in[gi]:0;
    __syncthreads();
    for(int d=1;d<256;d<<=1){int t=(tid>=d)?s[tid-d]:0;__syncthreads();s[tid]+=t;__syncthreads();}
    if(gi<n) out[gi]=s[tid];
}
