
// Bit deposit/extract patterns (BMI2-like, emulated on GPU via LOP3)
// pdep: scatter bits of source to positions marked in mask
// pext: gather bits from positions marked in mask
extern "C" __global__ void __launch_bounds__(128)
bit_deposit(unsigned *out, const unsigned *src, const unsigned *mask, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned s=src[i], m=mask[i], r=0;
    // Software pdep: scatter bits of s to positions in m
    for(unsigned bit=1,j=0;m;bit<<=1){
        if(m&1){if(s&(1u<<j))r|=bit;j++;}
        m>>=1; bit<<=1;
    }
    out[i]=r;
}

extern "C" __global__ void __launch_bounds__(128)
bit_extract(unsigned *out, const unsigned *src, const unsigned *mask, int n) {
    int i=threadIdx.x+blockIdx.x*blockDim.x;
    if(i>=n)return;
    unsigned s=src[i]&mask[i], m=mask[i], r=0;
    // Software pext: gather bits from positions in m
    for(unsigned bit=1;m;m>>=1,s>>=1){
        if(m&1){if(s&1)r|=bit;bit<<=1;}
    }
    out[i]=r;
}
