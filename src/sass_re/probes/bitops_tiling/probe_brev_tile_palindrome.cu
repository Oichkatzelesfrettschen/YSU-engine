
// Check if value is a bitwise palindrome
extern "C" __global__ void __launch_bounds__(128)
brev_palindrome(int *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    out[i]=(in[i]==__brev(in[i]))?1:0;
}
