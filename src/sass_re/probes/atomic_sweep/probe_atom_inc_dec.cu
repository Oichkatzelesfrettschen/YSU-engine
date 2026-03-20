
// Wrapping increment: atomicInc(addr, limit) = (old >= limit) ? 0 : old+1
extern "C" __global__ void __launch_bounds__(128)
atom_inc(unsigned *counter, unsigned limit, int iters) {
    for(int j=0;j<iters;j++) atomicInc(counter, limit); // ATOM.E.INC?
}

// Wrapping decrement: atomicDec(addr, limit) = (old==0 || old>limit) ? limit : old-1
extern "C" __global__ void __launch_bounds__(128)
atom_dec(unsigned *counter, unsigned limit, int iters) {
    for(int j=0;j<iters;j++) atomicDec(counter, limit); // ATOM.E.DEC?
}

// Shared memory inc/dec
extern "C" __global__ void __launch_bounds__(128)
atoms_inc_dec(unsigned *out, unsigned limit) {
    __shared__ unsigned s_inc, s_dec;
    if(threadIdx.x==0){s_inc=0;s_dec=limit;}
    __syncthreads();
    for(int j=0;j<100;j++){
        atomicInc(&s_inc, limit); // ATOMS.INC?
        atomicDec(&s_dec, limit); // ATOMS.DEC?
    }
    __syncthreads();
    if(threadIdx.x==0){out[blockIdx.x*2]=s_inc;out[blockIdx.x*2+1]=s_dec;}
}
