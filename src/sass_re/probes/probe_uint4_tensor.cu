/*
 * SASS RE Probe: UINT4 (Unsigned 4-bit Integer) Tensor Core
 * Isolates: IMMA.8832.U4.U4 (unsigned INT4 tensor MMA)
 *
 * Ada SM 8.9 tensor cores support both signed (S4) and unsigned (U4)
 * 4-bit integer matrix multiply. The signed variant was confirmed in
 * probe_4bit_formats.cu. This probe verifies the unsigned path.
 *
 * IMMA.8832.U4.U4 uses the same 8x8x32 shape as S4 but with unsigned
 * saturation (range [0, 15] instead of [-8, 7]).
 *
 * Key SASS: IMMA.8832.U4.U4
 */

#include <mma.h>
using namespace nvcuda;

__global__ void __launch_bounds__(32)
probe_uint4_tensor(int *d_D, const void *d_A, const void *d_B,
                   const int *d_C) {
    using namespace nvcuda::wmma::experimental;
    // Unsigned INT4: u4 precision
    wmma::fragment<wmma::matrix_a, 8, 8, 32, precision::u4, wmma::row_major> frag_A;
    wmma::fragment<wmma::matrix_b, 8, 8, 32, precision::u4, wmma::col_major> frag_B;
    wmma::fragment<wmma::accumulator, 8, 8, 32, int> frag_C;

    wmma::load_matrix_sync(frag_A, d_A, 32);
    wmma::load_matrix_sync(frag_B, d_B, 32);
    wmma::fill_fragment(frag_C, 0);

    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);

    wmma::store_matrix_sync(d_D, frag_C, 8, wmma::mem_row_major);
}

// Chained U4 IMMA for throughput measurement
__global__ void __launch_bounds__(32)
probe_uint4_tensor_chain(int *d_D, const void *d_A, const void *d_B) {
    using namespace nvcuda::wmma::experimental;
    wmma::fragment<wmma::matrix_a, 8, 8, 32, precision::u4, wmma::row_major> frag_A;
    wmma::fragment<wmma::matrix_b, 8, 8, 32, precision::u4, wmma::col_major> frag_B;
    wmma::fragment<wmma::accumulator, 8, 8, 32, int> frag_C;

    wmma::load_matrix_sync(frag_A, d_A, 32);
    wmma::load_matrix_sync(frag_B, d_B, 32);
    wmma::fill_fragment(frag_C, 0);

    // 8 back-to-back U4 IMMA
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);
    wmma::mma_sync(frag_C, frag_A, frag_B, frag_C);

    wmma::store_matrix_sync(d_D, frag_C, 8, wmma::mem_row_major);
}
