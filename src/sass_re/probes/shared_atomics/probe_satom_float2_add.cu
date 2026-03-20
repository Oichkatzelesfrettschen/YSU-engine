
// Float2 shared atomic: atomicAdd on 2 consecutive floats (not native)
extern "C" __global__ void __launch_bounds__(128)
satom_f2_add(float *out, const float2 *in, int n) {
    __shared__ float s_x, s_y;
    if(threadIdx.x==0){s_x=0;s_y=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float2 v=in[gi];
        atomicAdd(&s_x,v.x);
        atomicAdd(&s_y,v.y);
    }
    __syncthreads();
    if(threadIdx.x==0){atomicAdd(&out[0],s_x);atomicAdd(&out[1],s_y);}
}
