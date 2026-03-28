
// Shared atomic bitwise ops: AND, OR, XOR
extern "C" __global__ void __launch_bounds__(128)
satom_i32_bitwise(int *out, const int *in, int n) {
    __shared__ int s_and, s_or, s_xor;
    if(threadIdx.x==0){s_and=0xFFFFFFFF;s_or=0;s_xor=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        atomicAnd(&s_and,in[gi]);
        atomicOr(&s_or,in[gi]);
        atomicXor(&s_xor,in[gi]);
    }
    __syncthreads();
    if(threadIdx.x==0){out[blockIdx.x*3]=s_and;out[blockIdx.x*3+1]=s_or;out[blockIdx.x*3+2]=s_xor;}
}
