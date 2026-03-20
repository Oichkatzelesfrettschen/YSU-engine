
// INT64 comparison chain
extern "C" __global__ void __launch_bounds__(128)
int64_compare(int *out, const long long *a, const long long *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=(a[i]>b[i])?1:((a[i]<b[i])?-1:0);
}
