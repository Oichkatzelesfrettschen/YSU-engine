/*
 * SASS RE Probe: Cooperative Groups Synchronization Variants
 * Isolates: thread_block.sync, tiled_partition.sync, coalesced.sync
 *
 * Cooperative groups provide type-safe sync at different granularities.
 * Each generates different SASS barrier instructions.
 */

#include <cooperative_groups.h>
namespace cg = cooperative_groups;

// Thread block sync via cooperative groups API
extern "C" __global__ void __launch_bounds__(256)
probe_cg_block_sync(float *out, const float *in) {
    auto block = cg::this_thread_block();
    __shared__ float s[256];
    s[block.thread_rank()] = in[block.thread_rank() + blockIdx.x * 256];
    block.sync();  // Should generate BAR.SYNC
    out[block.thread_rank() + blockIdx.x * 256] = s[255 - block.thread_rank()];
}

// Tiled partition sync (32-thread tile = warp)
extern "C" __global__ void __launch_bounds__(256)
probe_cg_tile32_sync(float *out, const float *in) {
    auto block = cg::this_thread_block();
    auto warp = cg::tiled_partition<32>(block);
    float val = in[threadIdx.x + blockIdx.x * 256];
    // Warp-level sync via tiled partition
    warp.sync();
    float neighbor = warp.shfl_xor(val, 1);
    warp.sync();
    out[threadIdx.x + blockIdx.x * 256] = val + neighbor;
}

// Tiled partition sync (16-thread tile = half-warp)
extern "C" __global__ void __launch_bounds__(256)
probe_cg_tile16_sync(float *out, const float *in) {
    auto block = cg::this_thread_block();
    auto tile = cg::tiled_partition<16>(block);
    float val = in[threadIdx.x + blockIdx.x * 256];
    tile.sync();
    float sum = val;
    for (int off = tile.size()/2; off > 0; off /= 2)
        sum += tile.shfl_xor(sum, off);
    tile.sync();
    out[threadIdx.x + blockIdx.x * 256] = sum;
}

// Tiled partition sync (4-thread tile = sub-warp)
extern "C" __global__ void __launch_bounds__(256)
probe_cg_tile4_sync(float *out, const float *in) {
    auto block = cg::this_thread_block();
    auto tile = cg::tiled_partition<4>(block);
    float val = in[threadIdx.x + blockIdx.x * 256];
    tile.sync();
    float sum = val;
    for (int off = 2; off > 0; off /= 2)
        sum += tile.shfl_xor(sum, off);
    out[threadIdx.x + blockIdx.x * 256] = sum;
}

// Coalesced threads sync (dynamic subset)
extern "C" __global__ void __launch_bounds__(256)
probe_cg_coalesced_sync(float *out, const float *in) {
    float val = in[threadIdx.x + blockIdx.x * 256];
    if (val > 0.5f) {
        auto active = cg::coalesced_threads();
        active.sync();
        float sum = val;
        for (int off = active.size()/2; off > 0; off /= 2)
            sum += active.shfl_down(sum, off);
        if (active.thread_rank() == 0)
            out[blockIdx.x] = sum;
    }
}

// Multi-level sync: block.sync + warp.sync + tile.sync in same kernel
extern "C" __global__ void __launch_bounds__(256)
probe_cg_multilevel_sync(float *out, const float *in) {
    auto block = cg::this_thread_block();
    auto warp = cg::tiled_partition<32>(block);
    auto quad = cg::tiled_partition<4>(block);

    __shared__ float s[256];
    s[threadIdx.x] = in[threadIdx.x + blockIdx.x * 256];
    block.sync();   // Full block sync

    float val = s[threadIdx.x];
    // Quad-level reduction
    float qsum = val;
    for (int off = 2; off > 0; off /= 2)
        qsum += quad.shfl_xor(qsum, off);
    quad.sync();

    // Warp-level aggregation
    if (quad.thread_rank() == 0) {
        float wsum = qsum;
        for (int off = 16; off >= 4; off /= 2)
            wsum += warp.shfl_xor(wsum, off);
        warp.sync();
        if (warp.thread_rank() == 0) s[threadIdx.x / 32] = wsum;
    }

    block.sync();
    if (threadIdx.x < 8) {
        out[blockIdx.x * 8 + threadIdx.x] = s[threadIdx.x];
    }
}
