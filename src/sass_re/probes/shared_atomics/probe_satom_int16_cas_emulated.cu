
// INT16 shared atomic via CAS on 32-bit word (no native INT16 atomic)
extern "C" __global__ void __launch_bounds__(128)
satom_i16_cas(short *out, const short *in, int n) {
    __shared__ int s_packed[64]; // 2 shorts per int
    int tid=threadIdx.x;
    if(tid<64) s_packed[tid]=0;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n){
        short val=in[gi];
        int word_idx=gi/2;
        int byte_offset=(gi%2)*16; // 0 or 16
        // CAS on containing 32-bit word
        int *addr=&s_packed[word_idx%64];
        int old=*addr;
        while(1){
            int new_val=(old&~(0xFFFF<<byte_offset))|((int)(val&0xFFFF)<<byte_offset);
            int prev=atomicCAS(addr,old,new_val);
            if(prev==old)break;
            old=prev;
        }
    }
    __syncthreads();
    if(tid<64) out[blockIdx.x*64+tid]=(short)(s_packed[tid]&0xFFFF);
}
