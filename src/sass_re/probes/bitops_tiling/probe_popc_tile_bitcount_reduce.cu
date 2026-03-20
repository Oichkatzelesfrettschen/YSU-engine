
// Block-level bit count reduction
extern "C" __global__ void __launch_bounds__(256)
popc_reduce(int *out, const unsigned *in, int n) {
    __shared__ int s[256];
    int tid=threadIdx.x, gi=blockIdx.x*256+tid;
    s[tid]=(gi<n)?__popc(in[gi]):0;
    __syncthreads();
    for(int st=128;st>0;st>>=1){if(tid<st)s[tid]+=s[tid+st];__syncthreads();}
    if(tid==0) atomicAdd(out,s[0]);
}
