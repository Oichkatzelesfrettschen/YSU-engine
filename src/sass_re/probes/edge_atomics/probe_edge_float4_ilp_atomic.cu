
// float4 accumulation: 4 independent shared atomicAdds per thread (ILP)
extern "C" __global__ void __launch_bounds__(128)
edge_f4_ilp_atomic(float *out, const float4 *in, int n) {
    __shared__ float sx,sy,sz,sw;
    if(threadIdx.x==0){sx=0;sy=0;sz=0;sw=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float4 v=in[gi];
        // 4 independent atomicAdds (can the SM interleave them?)
        atomicAdd(&sx,v.x);
        atomicAdd(&sy,v.y);
        atomicAdd(&sz,v.z);
        atomicAdd(&sw,v.w);
    }
    __syncthreads();
    if(threadIdx.x==0){
        atomicAdd(&out[0],sx);atomicAdd(&out[1],sy);
        atomicAdd(&out[2],sz);atomicAdd(&out[3],sw);
    }
}
