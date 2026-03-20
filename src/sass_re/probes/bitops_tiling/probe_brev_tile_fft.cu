
// FFT bit-reversal permutation
extern "C" __global__ void __launch_bounds__(256)
brev_fft_permute(float *out, const float *in, int log_n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    int n=1<<log_n;
    if(i>=n)return;
    int rev=__brev(i)>>(32-log_n);
    out[rev]=in[i];
}
