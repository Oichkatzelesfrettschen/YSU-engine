
// FP64 FMA result accumulated via shared CAS (highest precision atomic path)
extern "C" __global__ void __launch_bounds__(128)
edge2_fp64_fma_cas(double *out, const double *a, const double *b, const double *c, int n) {
    __shared__ double s_acc;
    if(threadIdx.x==0) s_acc=0.0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        double val=fma(a[gi],b[gi],c[gi]); // DFMA
        unsigned long long *addr=(unsigned long long*)&s_acc;
        unsigned long long old=*addr, assumed;
        do{assumed=old;old=atomicCAS(addr,assumed,__double_as_longlong(__longlong_as_double(assumed)+val));}while(assumed!=old);
    }
    __syncthreads();
    if(threadIdx.x==0){
        unsigned long long *g=(unsigned long long*)out;
        unsigned long long old=*g, assumed;
        do{assumed=old;old=atomicCAS(g,assumed,__double_as_longlong(__longlong_as_double(assumed)+s_acc));}while(assumed!=old);
    }
}
