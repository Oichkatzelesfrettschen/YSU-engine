
// NF8 encode: find nearest quantile via binary search
// SASS RE probe -- LUT is intentionally uninitialized here because the
// probe's purpose is to observe SASS instruction patterns (LDC, binary
// search structure), not to produce numerically correct output.  The LUT
// would be populated via cudaMemcpyToSymbol at runtime.
__constant__ float NF8_ENCODE_LUT[256];
extern "C" __global__ void __launch_bounds__(128)
nf8_tile_encode(unsigned char *out, const float *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    float val=in[i];
    // Binary search over 256 sorted values
    int lo=0, hi=255;
    while(lo<hi){
        int mid=(lo+hi)/2;
        if(NF8_ENCODE_LUT[mid]<val) lo=mid+1; else hi=mid;
    }
    out[i]=(unsigned char)lo;
}
