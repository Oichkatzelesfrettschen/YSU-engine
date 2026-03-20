
// Population density: POPC chain for latency
extern "C" __global__ void __launch_bounds__(32)
popc_chain_lat(volatile unsigned *vals, volatile long long *out) {
    unsigned x=vals[0]; long long t0,t1;
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t0));
    #pragma unroll
    for(int i=0;i<512;i++){unsigned c;asm volatile("popc.b32 %0,%1;":"=r"(c):"r"(x));asm volatile("or.b32 %0,%1,0xff;":"=r"(x):"r"(c));}
    asm volatile("mov.u64 %0, %%clock64;":"=l"(t1));
    vals[3]=x;
    if(threadIdx.x==0){out[0]=t1-t0;out[1]=1024;}
}
