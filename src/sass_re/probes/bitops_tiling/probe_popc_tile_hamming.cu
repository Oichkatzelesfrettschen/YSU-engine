
// Hamming distance via POPC(XOR)
extern "C" __global__ void __launch_bounds__(128)
popc_hamming(int *dist, const unsigned *a, const unsigned *b, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    dist[i]=__popc(a[i]^b[i]);
}
