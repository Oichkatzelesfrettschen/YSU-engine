
// CRC-like computation using BREV for bit-order reversal
extern "C" __global__ void __launch_bounds__(128)
brev_crc(unsigned *out, const unsigned *in, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned v=in[i], crc=0xFFFFFFFF;
    #pragma unroll
    for(int b=0;b<32;b++){
        unsigned bit=((v>>b)^crc)&1;
        crc=(crc>>1)^(0xEDB88320u*bit);
    }
    out[i]=__brev(crc^0xFFFFFFFF);
}
