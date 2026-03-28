
#include <cuda_fp16.h>
#include <string.h>
// Half2 warp shuffle (shuffles packed FP16 pair)
extern "C" __global__ void __launch_bounds__(32)
dm_shfl_half2(__half2 *out, const __half2 *in) {
    int tid=threadIdx.x;
    __half2 val=in[tid];
    // Bit-cast half2 to unsigned for shuffle (memcpy avoids type-punning UB)
    unsigned bits;
    memcpy(&bits, &val, sizeof(bits));
    bits=__shfl_xor_sync(0xFFFFFFFF,bits,1);
    memcpy(&val, &bits, sizeof(val));
    out[tid]=val;
}
