
// SIMD-style shared atomic: vectorized load + warp reduce + single atomic
extern "C" __global__ void __launch_bounds__(128)
satom_simd_reduce(float *out, const float4 *in, int n) {
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    float sum=0.0f;
    if(gi<n){
        float4 v=in[gi];
        sum=v.x+v.y+v.z+v.w; // 4-wide SIMD-like sum
    }
    // Warp reduce
    sum+=__shfl_xor_sync(0xFFFFFFFF,sum,16);
    sum+=__shfl_xor_sync(0xFFFFFFFF,sum,8);
    sum+=__shfl_xor_sync(0xFFFFFFFF,sum,4);
    sum+=__shfl_xor_sync(0xFFFFFFFF,sum,2);
    sum+=__shfl_xor_sync(0xFFFFFFFF,sum,1);
    // Single atomic per warp
    if((threadIdx.x&31)==0) atomicAdd(out,sum);
}
