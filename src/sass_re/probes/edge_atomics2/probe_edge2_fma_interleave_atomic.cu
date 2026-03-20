
// Interleave FMA compute with shared atomic writes (tests pipeline overlap)
extern "C" __global__ void __launch_bounds__(128)
edge2_fma_atomic_interleave(float *out, const float *in, int n, int depth) {
    __shared__ float s_bins[4];
    if(threadIdx.x<4) s_bins[threadIdx.x]=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        float a=in[gi], b=a;
        for(int d=0;d<depth;d++){
            // FMA compute
            a=fmaf(a,0.999f,0.001f);
            b=fmaf(b,0.998f,0.002f);
            // Interleaved atomic (every 4th iteration)
            if((d&3)==3) atomicAdd(&s_bins[d&3],a+b);
        }
        atomicAdd(&s_bins[gi&3],a);
    }
    __syncthreads();
    if(threadIdx.x<4) atomicAdd(&out[threadIdx.x],s_bins[threadIdx.x]);
}
