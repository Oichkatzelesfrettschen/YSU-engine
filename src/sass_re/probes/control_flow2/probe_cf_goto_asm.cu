
// Explicit branch via inline PTX (force specific branch types)
extern "C" __global__ void __launch_bounds__(128)
cf_ptx_branch(float *out, const float *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float v=in[i];
    // Uniform branch via PTX (all threads same direction)
    asm volatile(
        "{ .reg .pred p;"
        "  setp.gt.f32 p, %1, 0.5;"
        "  @p bra L_true_%=;"
        "  mul.f32 %0, %1, 2.0;"
        "  bra L_end_%=;"
        "  L_true_%=: add.f32 %0, %1, 1.0;"
        "  L_end_%=:;"
        "}" : "=f"(v) : "f"(v));
    out[i]=v;
}
