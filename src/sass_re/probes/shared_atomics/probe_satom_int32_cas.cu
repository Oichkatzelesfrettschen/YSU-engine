
// Shared atomic CAS (compare-and-swap) for lock-free update
extern "C" __global__ void __launch_bounds__(128)
satom_i32_cas(int *out, const int *in, int n) {
    __shared__ int s_val;
    if(threadIdx.x==0) s_val=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int val=in[gi];
        // CAS loop: atomically set s_val = max(s_val, val)
        int old=s_val;
        while(val>old){
            int prev=atomicCAS(&s_val,old,val);
            if(prev==old) break;
            old=prev;
        }
    }
    __syncthreads();
    if(threadIdx.x==0) out[blockIdx.x]=s_val;
}
