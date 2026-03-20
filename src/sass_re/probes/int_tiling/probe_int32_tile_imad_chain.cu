
// INT32 IMAD latency chain (dependent multiply-add)
extern "C" __global__ void __launch_bounds__(32)
int32_imad_chain(volatile int *vals, volatile long long *out) {
    int x=vals[0],y=vals[1],z=vals[2]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++) asm volatile("mad.lo.s32 %0,%0,%1,%2;":"+r"(x):"r"(y),"r"(z));
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[3]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=512;}
}
