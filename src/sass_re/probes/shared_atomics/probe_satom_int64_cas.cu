
// Shared atomic INT64 CAS
extern "C" __global__ void __launch_bounds__(128)
satom_i64_cas(unsigned long long *out, const unsigned long long *in, int n) {
    __shared__ unsigned long long s_val;
    if(threadIdx.x==0) s_val=0ULL;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        unsigned long long val=in[gi];
        unsigned long long old=s_val;
        while(val>old){
            unsigned long long prev=atomicCAS(&s_val,old,val);
            if(prev==old)break;
            old=prev;
        }
    }
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s_val;
}
