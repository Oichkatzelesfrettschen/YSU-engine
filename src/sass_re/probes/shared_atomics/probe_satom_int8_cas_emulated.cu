
// INT8 shared atomic via CAS on 32-bit word (no native INT8 atomic)
extern "C" __global__ void __launch_bounds__(128)
satom_i8_cas(signed char *out, const signed char *in, int n) {
    __shared__ int s_packed[32]; // 4 bytes per int
    int tid=threadIdx.x;
    if(tid<32) s_packed[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n){
        signed char val=in[gi];
        int word_idx=gi/4;
        int byte_shift=(gi%4)*8;
        int *addr=&s_packed[word_idx%32];
        int old=*addr;
        while(1){
            int new_val=(old&~(0xFF<<byte_shift))|(((int)(val&0xFF))<<byte_shift);
            int prev=atomicCAS(addr,old,new_val);
            if(prev==old)break;
            old=prev;
        }
    }
    __syncthreads();
    if(tid<32) out[blockIdx.x*32+tid]=(signed char)(s_packed[tid]&0xFF);
}
