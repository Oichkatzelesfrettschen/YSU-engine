
// Shared atomic FLOAT max via CAS (no native atomicMax for float)
extern "C" __global__ void __launch_bounds__(128)
satom_f32_max_cas(float *out, const float *in, int n) {
    __shared__ float s_max;
    if(threadIdx.x==0) s_max=-1e30f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float val=in[gi];
        // CAS-based atomicMax for float
        int *addr=(int*)&s_max;
        int old=*addr;
        while(val>__int_as_float(old)){
            int prev=atomicCAS(addr,old,__float_as_int(val));
            if(prev==old) break;
            old=prev;
        }
    }
    __syncthreads();
    if(threadIdx.x==0){
        // Global CAS-max
        int *g=(int*)out;
        int old=*g;
        float sval=s_max;
        while(sval>__int_as_float(old)){
            int prev=atomicCAS(g,old,__float_as_int(sval));
            if(prev==old)break;
            old=prev;
        }
    }
}
