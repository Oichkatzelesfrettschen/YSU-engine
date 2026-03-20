
// BREV latency chain (pure, no feedback mangling)
extern "C" __global__ void __launch_bounds__(32)
brev_chain_lat(volatile unsigned *vals, volatile long long *out) {
    unsigned x=vals[0]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++) asm volatile("brev.b32 %0,%0;":"+r"(x));
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[3]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=512;}
}
