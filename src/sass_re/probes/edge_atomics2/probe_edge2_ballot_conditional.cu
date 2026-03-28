
// Ballot-masked conditional: only threads in specific ballot pattern do atomic
extern "C" __global__ void __launch_bounds__(128)
edge2_ballot_cond(int *out, const float *in, float lo, float hi, int n) {
    __shared__ int s_in_range, s_below, s_above;
    if(threadIdx.x<3){int *p[]={&s_in_range,&s_below,&s_above};*p[threadIdx.x]=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float v=in[gi];
        unsigned active=__activemask();
        unsigned in_range=__ballot_sync(active,v>=lo&&v<=hi);
        unsigned below=__ballot_sync(active,v<lo);
        unsigned above=__ballot_sync(active,v>hi);
        // Only lane 0 does atomic (3 bins)
        if((threadIdx.x&31)==0){
            atomicAdd(&s_in_range,__popc(in_range));
            atomicAdd(&s_below,__popc(below));
            atomicAdd(&s_above,__popc(above));
        }
    }
    __syncthreads();
    if(threadIdx.x==0){atomicAdd(&out[0],s_in_range);atomicAdd(&out[1],s_below);atomicAdd(&out[2],s_above);}
}
