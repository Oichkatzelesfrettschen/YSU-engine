
// INT64 accumulation (sum reduction)
extern "C" __global__ void __launch_bounds__(128)
int64_accumulate(unsigned long long *out, const long long *in, int n) {
    __shared__ long long s[128];
    int tid=threadIdx.x, gi=blockIdx.x*128+tid;
    s[tid]=(gi<n)?in[gi]:0LL;
    __syncthreads();
    for(int st=64;st>0;st>>=1){if(tid<st)s[tid]+=s[tid+st];__syncthreads();}
    if(tid==0) atomicAdd(out,(unsigned long long)s[0]);
}
