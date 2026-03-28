
// IABS latency chain (negate-then-abs, avoids idempotent folding)
extern "C" __global__ void __launch_bounds__(32)
iabs_chain_lat(volatile int *vals, volatile long long *out) {
    int x=vals[0]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++){asm volatile("neg.s32 %0,%0;":"+r"(x));asm volatile("abs.s32 %0,%0;":"+r"(x));}
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[3]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=1024;}
}
