
// Sum of Absolute Differences (SAD) for block matching
extern "C" __global__ void __launch_bounds__(128)
int8_sad(int *out, const signed char *a, const signed char *b, int block_size, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    int sad=0;
    int base=i*block_size;
    for(int j=0;j<block_size;j++) sad+=abs((int)a[base+j]-(int)b[base+j]);
    out[i]=sad;
}
