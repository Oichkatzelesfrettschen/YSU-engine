
// LD.E / ST.E (generic, non-global, non-shared)
// These are the "generic" load/store that can target any memory space
extern "C" __global__ void __launch_bounds__(128)
dm2_generic_load(float *out, const float *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float v;
    // Generic load without address space qualifier is intentional: the probe
    // tests whether ptxas resolves generic addresses to global LD/ST or keeps
    // them as generic-space operations in the emitted SASS.
    asm volatile("ld.f32 %0, [%1];":"=f"(v):"l"(&in[i]));
    out[i]=v;
}
extern "C" __global__ void __launch_bounds__(128)
dm2_generic_store(float *out, const float *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float v=in[i]*2.0f;
    // Generic store without address space qualifier is intentional (see above).
    asm volatile("st.f32 [%0], %1;"::"l"(&out[i]),"f"(v));
}
