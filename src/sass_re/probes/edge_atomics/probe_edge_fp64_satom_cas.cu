
// FP64 shared atomic add via CAS loop (no native atomicAdd for double in smem)
extern "C" __global__ void __launch_bounds__(128)
edge_fp64_satom(double *out, const double *in, int n) {
    __shared__ double s_sum;
    if(threadIdx.x==0) s_sum=0.0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        double val=in[gi];
        // CAS loop on double (reinterpret as unsigned long long)
        unsigned long long *addr=(unsigned long long*)&s_sum;
        unsigned long long old=*addr;
        unsigned long long assumed;
        do{
            assumed=old;
            old=atomicCAS(addr,assumed,__double_as_longlong(__longlong_as_double(assumed)+val));
        }while(assumed!=old);
    }
    __syncthreads();
    if(threadIdx.x==0){
        // Global CAS for double
        unsigned long long *g=(unsigned long long*)out;
        unsigned long long old=*g;
        unsigned long long assumed;
        do{
            assumed=old;
            old=atomicCAS(g,assumed,__double_as_longlong(__longlong_as_double(assumed)+s_sum));
        }while(assumed!=old);
    }
}
