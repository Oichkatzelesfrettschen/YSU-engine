
// NF4 weighted accumulation: decode NF4, multiply by weight, atomic sum
__constant__ float NF4_W[16]={-1.0f,-0.6962f,-0.5251f,-0.3949f,-0.2844f,-0.1848f,-0.09105f,0.0f,
                               0.07959f,0.1609f,0.2461f,0.3379f,0.4407f,0.5626f,0.7230f,1.0f};
extern "C" __global__ void __launch_bounds__(128)
edge2_nf4_weighted(float *out, const unsigned char *nf4_packed, const float *weights, int n_bytes) {
    __shared__ float s_sum;
    if(threadIdx.x==0) s_sum=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n_bytes){
        unsigned char b=nf4_packed[gi];
        float v0=NF4_W[b&0xF]*weights[gi*2];
        float v1=NF4_W[(b>>4)&0xF]*weights[gi*2+1];
        atomicAdd(&s_sum,v0+v1);
    }
    __syncthreads();
    if(threadIdx.x==0) atomicAdd(out,s_sum);
}
