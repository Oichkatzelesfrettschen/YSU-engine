
#include <mma.h>
using namespace nvcuda;
// INT4 tensor core output atomicMax on shared memory
__global__ void __launch_bounds__(32)
edge2_int4_tc_max(int *out, const void *A, const void *B) {
    using namespace nvcuda::wmma::experimental;
    wmma::fragment<wmma::matrix_a,8,8,32,precision::s4,wmma::row_major> fA;
    wmma::fragment<wmma::matrix_b,8,8,32,precision::s4,wmma::col_major> fB;
    wmma::fragment<wmma::accumulator,8,8,32,int> fC;
    wmma::load_matrix_sync(fA,A,32);
    wmma::load_matrix_sync(fB,B,32);
    wmma::fill_fragment(fC,0);
    wmma::mma_sync(fC,fA,fB,fC);
    // Find max accumulator element via shared atomic
    __shared__ int s_max;
    if(threadIdx.x==0) s_max=0x80000000;
    __syncwarp();
    for(int i=0;i<fC.num_elements;i++) atomicMax(&s_max,fC.x[i]);
    __syncwarp();
    if(threadIdx.x==0) atomicMax(out,s_max);
}
