
#include <mma.h>
using namespace nvcuda;
// TF32 TC matmul output reduced via shared atomic
extern "C" __global__ void __launch_bounds__(32)
edge2_tf32_tc_reduce(float *out, const float *A, const float *B) {
    wmma::fragment<wmma::matrix_a,16,16,8,wmma::precision::tf32,wmma::row_major> fA;
    wmma::fragment<wmma::matrix_b,16,16,8,wmma::precision::tf32,wmma::col_major> fB;
    wmma::fragment<wmma::accumulator,16,16,8,float> fC;
    wmma::load_matrix_sync(fA,A,16);
    wmma::load_matrix_sync(fB,B,16);
    wmma::fill_fragment(fC,0.0f);
    wmma::mma_sync(fC,fA,fB,fC);
    // Sum all accumulator elements via shared atomic
    __shared__ float s_total;
    if(threadIdx.x==0) s_total=0.0f;
    __syncwarp();
    float local_sum=0.0f;
    for(int i=0;i<fC.num_elements;i++) local_sum+=fC.x[i];
    atomicAdd(&s_total,local_sum);
    __syncwarp();
    if(threadIdx.x==0) atomicAdd(out,s_total);
}
