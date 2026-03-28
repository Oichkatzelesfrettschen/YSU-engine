
// Abs-based branchless min/max
extern "C" __global__ void __launch_bounds__(128)
iabs_minmax(int *out_min, int *out_max, const int *a, const int *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int va=a[i],vb=b[i];
    int diff=va-vb;
    int ad=abs(diff);
    // min = (a+b-|a-b|)/2, max = (a+b+|a-b|)/2
    out_min[i]=(va+vb-ad)>>1;
    out_max[i]=(va+vb+ad)>>1;
}
