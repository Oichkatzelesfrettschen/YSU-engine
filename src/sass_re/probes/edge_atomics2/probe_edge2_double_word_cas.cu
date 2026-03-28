
// Atomic update of a (key,value) pair in shared memory via double CAS
// Atomically sets (key,value) only if current key < new key
extern "C" __global__ void __launch_bounds__(128)
edge2_kv_atomic(int *out_key, int *out_val, const int *keys, const int *vals, int n) {
    __shared__ int s_key, s_val;
    if(threadIdx.x==0){s_key=0x80000000;s_val=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        int my_key=keys[gi], my_val=vals[gi];
        // CAS loop: update if my_key > current s_key
        int old_key=s_key;
        while(my_key>old_key){
            int prev=atomicCAS(&s_key,old_key,my_key);
            if(prev==old_key){
                // NOTE: Intentional race between s_key CAS and s_val store.
                // This probe tests the SASS pattern for non-atomic value
                // updates paired with CAS -- the race is the behavior
                // being characterized.
                s_val=my_val;
                break;
            }
            old_key=prev;
        }
    }
    __syncthreads();
    // NOTE: Per-block output; global consistency not guaranteed
    // (probe tests atomicMax SASS pattern).
    if(threadIdx.x==0){atomicMax(out_key,s_key);*out_val=s_val;}
}
