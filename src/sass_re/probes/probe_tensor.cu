/*
 * SASS RE Probe: Tensor Core (HMMA)
 * Isolates: HMMA (half-precision matrix multiply-accumulate) via WMMA API
 *
 * Ada Lovelace SM 8.9 tensor cores support:
 *   FP16 accumulate to FP16/FP32 (HMMA.16816)
 *   BF16 accumulate to FP32
 *   TF32 accumulate to FP32
 *   INT8 accumulate to INT32 (IMMA)
 *
 * The wmma API is the cleanest way to generate tensor core SASS
 * without writing PTX inline assembly.
 */

#include <mma.h>
using namespace nvcuda;

// FP16 matrix multiply: D = A*B + C  (16x16x16)
extern "C" __global__ void __launch_bounds__(32)
probe_hmma_fp16(half *d_D, const half *d_A, const half *d_B, const float *d_C) {
    // Declare fragments for 16x16x16 HMMA
    wmma::fragment<wmma::matrix_a, 16, 16, 16, half, wmma::row_major> frag_A;
    wmma::fragment<wmma::matrix_b, 16, 16, 16, half, wmma::col_major> frag_B;
    wmma::fragment<wmma::accumulator, 16, 16, 16, float> frag_C;
    wmma::fragment<wmma::accumulator, 16, 16, 16, half> frag_D;

    // Load inputs from global memory
    wmma::load_matrix_sync(frag_A, d_A, 16);
    wmma::load_matrix_sync(frag_B, d_B, 16);
    wmma::load_matrix_sync(frag_C, d_C, 16, wmma::mem_row_major);

    // The actual HMMA instruction(s):
    wmma::mma_sync(frag_D, frag_A, frag_B, frag_C);

    // Store result
    wmma::store_matrix_sync(d_D, frag_D, 16, wmma::mem_row_major);
}

// Chain of HMMA ops to see pipeline throughput
extern "C" __global__ void __launch_bounds__(32)
probe_hmma_chain(half *d_D, const half *d_A, const half *d_B, const float *d_C) {
    wmma::fragment<wmma::matrix_a, 16, 16, 16, half, wmma::row_major> frag_A;
    wmma::fragment<wmma::matrix_b, 16, 16, 16, half, wmma::col_major> frag_B;
    wmma::fragment<wmma::accumulator, 16, 16, 16, float> frag_C;
    wmma::fragment<wmma::accumulator, 16, 16, 16, half> frag_D;

    wmma::load_matrix_sync(frag_A, d_A, 16);
    wmma::load_matrix_sync(frag_B, d_B, 16);
    wmma::fill_fragment(frag_C, 0.0f);

    // Back-to-back HMMA to saturate the tensor core pipeline
    wmma::mma_sync(frag_D, frag_A, frag_B, frag_C);
    // Reload A from D for chaining (type mismatch, but shows the pattern)
    wmma::store_matrix_sync(d_D, frag_D, 16, wmma::mem_row_major);
    wmma::load_matrix_sync(frag_A, d_D, 16);
    wmma::mma_sync(frag_D, frag_A, frag_B, frag_C);
    wmma::store_matrix_sync(d_D, frag_D, 16, wmma::mem_row_major);
    wmma::load_matrix_sync(frag_A, d_D, 16);
    wmma::mma_sync(frag_D, frag_A, frag_B, frag_C);
    wmma::store_matrix_sync(d_D, frag_D, 16, wmma::mem_row_major);
    wmma::load_matrix_sync(frag_A, d_D, 16);
    wmma::mma_sync(frag_D, frag_A, frag_B, frag_C);

    wmma::store_matrix_sync(d_D, frag_D, 16, wmma::mem_row_major);
}
