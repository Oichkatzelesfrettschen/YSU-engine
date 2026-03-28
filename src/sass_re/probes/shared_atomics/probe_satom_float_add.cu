
// Shared atomic FLOAT add (FP32 atomicAdd on shared memory)
extern "C" __global__ void __launch_bounds__(128)
satom_f32_add(float *out, const float *in, int n) {
    __shared__ float s_sum[32];
    int tid=threadIdx.x;
    if(tid<32) s_sum[tid]=0.0f;
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+tid;
    if(gi<n) atomicAdd(&s_sum[tid%32],in[gi]); // FP32 shared atomic
    __syncthreads();
    if(tid<32) atomicAdd(&out[tid],s_sum[tid]);
}
