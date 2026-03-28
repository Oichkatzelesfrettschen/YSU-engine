
// INT64 shift chain
extern "C" __global__ void __launch_bounds__(32)
int64_shift_chain(volatile unsigned long long *vals, volatile long long *out) {
    unsigned long long x=vals[0]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++) asm volatile("shl.b64 %0,%0,3;":"+l"(x));
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[2]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=512;}
}
