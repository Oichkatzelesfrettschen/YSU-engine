
// Parallel POPC on 4 independent streams (throughput)
extern "C" __global__ void __launch_bounds__(1024)
popc_throughput(volatile unsigned *sink) {
    unsigned a0=0xDEADBEEF,a1=0xCAFEBABE,a2=0x12345678,a3=0x87654321;
    int c0=0,c1=0,c2=0,c3=0;
    #pragma unroll 1
    for(int i=0;i<512;i++){
        c0+=__popc(a0); a0=a0*1664525u+c0;
        c1+=__popc(a1); a1=a1*1664525u+c1;
        c2+=__popc(a2); a2=a2*1664525u+c2;
        c3+=__popc(a3); a3=a3*1664525u+c3;
    }
    sink[threadIdx.x]=(unsigned)(c0+c1+c2+c3);
}
