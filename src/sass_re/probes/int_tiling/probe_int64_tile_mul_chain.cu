
// INT64 multiply latency chain
extern "C" __global__ void __launch_bounds__(32)
int64_mul_chain(volatile long long *vals, volatile long long *out) {
    long long x=vals[0],y=vals[1]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++) asm volatile("mul.lo.s64 %0,%0,%1;":"+l"(x):"l"(y));
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[2]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=512;}
}
