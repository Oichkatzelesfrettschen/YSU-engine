
// INT4 nibble-level atomic increment via CAS on containing byte
// Atomically increments a 4-bit counter (16 values per 4 bytes)
extern "C" __global__ void __launch_bounds__(128)
edge_int4_nibble_cas(unsigned *counters, const unsigned char *indices, int n) {
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi>=n)return;
    int nibble_idx=indices[gi]&0xF; // Which nibble (0-7 in a 32-bit word)
    int word_idx=nibble_idx/8;
    int nibble_pos=(nibble_idx%8)*4;
    // CAS loop to atomically increment the nibble
    unsigned *addr=&counters[word_idx];
    unsigned old=*addr;
    while(1){
        unsigned nibble_val=(old>>nibble_pos)&0xF;
        if(nibble_val>=15) break; // Saturate at 15
        unsigned new_val=(old&~(0xFu<<nibble_pos))|((nibble_val+1)<<nibble_pos);
        unsigned prev=atomicCAS(addr,old,new_val);
        if(prev==old)break;
        old=prev;
    }
}
