/*
 * SASS RE Probe: Warp-Level Shuffle Reduction and Advanced Warp Primitives
 * Isolates: SHFL.DOWN, SHFL.BFLY, SHFL.IDX, SHFL.UP, VOTE, MATCH, REDUX
 *
 * Warp shuffle is the primary intra-warp communication mechanism on Ada.
 * From SASS RE: SHFL.BFLY latency = 24.96 cycles.
 *
 * Reduction patterns:
 *   Butterfly (log2 depth): 5 SHFL.BFLY ops for 32-lane reduction
 *   Sequential (linear): 31 SHFL.DOWN ops (suboptimal, but shows pipeline)
 *
 * Advanced warp primitives (Ada Lovelace):
 *   __ballot_sync: VOTE.SYNC.ALL/ANY -> ballot mask
 *   __activemask: Returns active thread mask
 *   __match_all_sync: MATCH.ALL -> checks if all active threads have same value
 *   __reduce_add_sync: REDUX.ADD (hardware warp reduction, SM 8.0+)
 *   __reduce_min_sync: REDUX.MIN
 *   __reduce_max_sync: REDUX.MAX
 *
 * Key SASS instructions:
 *   SHFL.BFLY   -- butterfly shuffle (XOR of lane IDs)
 *   SHFL.DOWN   -- shift down by delta lanes
 *   SHFL.UP     -- shift up by delta lanes
 *   SHFL.IDX    -- arbitrary lane-to-lane
 *   VOTE.ALL    -- all-active predicate
 *   VOTE.ANY    -- any-active predicate
 *   VOTE.BALLOT -- bitfield of active lanes
 *   MATCH.ALL   -- check uniform value across active lanes
 *   REDUX.SUM   -- hardware 32-lane reduction (SM 8.0+)
 *   REDUX.MIN   -- hardware min reduction
 *   REDUX.MAX   -- hardware max reduction
 */

// Classic butterfly warp reduction (5 SHFL.BFLY ops)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_reduce_butterfly(float *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    // Butterfly reduction: log2(32) = 5 stages
    val += __shfl_xor_sync(0xFFFFFFFF, val, 16);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 8);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 4);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 2);
    val += __shfl_xor_sync(0xFFFFFFFF, val, 1);

    if (i == 0) out[0] = val;
}

// Sequential down-shift reduction (5 SHFL.DOWN ops)
extern "C" __global__ void __launch_bounds__(32)
probe_warp_reduce_down(float *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    val += __shfl_down_sync(0xFFFFFFFF, val, 16);
    val += __shfl_down_sync(0xFFFFFFFF, val, 8);
    val += __shfl_down_sync(0xFFFFFFFF, val, 4);
    val += __shfl_down_sync(0xFFFFFFFF, val, 2);
    val += __shfl_down_sync(0xFFFFFFFF, val, 1);

    if (i == 0) out[0] = val;
}

// Hardware warp reduction (REDUX instruction, SM 8.0+)
// Single instruction replaces 5-stage shuffle tree
extern "C" __global__ void __launch_bounds__(32)
probe_redux_add(int *out, const int *in) {
    int i = threadIdx.x;
    int val = in[i];

    // REDUX.SUM: hardware 32-lane integer reduction
    int sum = __reduce_add_sync(0xFFFFFFFF, val);

    if (i == 0) out[0] = sum;
}

extern "C" __global__ void __launch_bounds__(32)
probe_redux_min_max(int *out_min, int *out_max, const int *in) {
    int i = threadIdx.x;
    int val = in[i];

    // REDUX.MIN and REDUX.MAX
    int warp_min = __reduce_min_sync(0xFFFFFFFF, val);
    int warp_max = __reduce_max_sync(0xFFFFFFFF, val);

    if (i == 0) {
        out_min[0] = warp_min;
        out_max[0] = warp_max;
    }
}

// Warp vote operations (VOTE instruction)
extern "C" __global__ void __launch_bounds__(32)
probe_vote_ballot(unsigned int *out_ballot, int *out_popc,
                  const float *in, float threshold) {
    int i = threadIdx.x;
    float val = in[i];
    int pred = (val > threshold);

    // VOTE.BALLOT: returns bitmask of threads where predicate is true
    unsigned int ballot = __ballot_sync(0xFFFFFFFF, pred);

    // POPC on ballot result: count active lanes meeting condition
    int count = __popc(ballot);

    // VOTE.ALL: true if ALL threads satisfy predicate
    int all = __all_sync(0xFFFFFFFF, pred);

    // VOTE.ANY: true if ANY thread satisfies predicate
    int any = __any_sync(0xFFFFFFFF, pred);

    if (i == 0) {
        out_ballot[0] = ballot;
        out_popc[0] = count;
        out_ballot[1] = (unsigned int)all;
        out_ballot[2] = (unsigned int)any;
    }
}

// Warp match operation (MATCH instruction, SM 7.0+)
extern "C" __global__ void __launch_bounds__(32)
probe_match_all(unsigned int *out_mask, int *out_pred,
                const int *in) {
    int i = threadIdx.x;
    int val = in[i];
    int pred;

    // MATCH.ALL: returns mask of threads with the same value as this thread
    unsigned int mask = __match_all_sync(0xFFFFFFFF, val, &pred);

    out_mask[i] = mask;
    out_pred[i] = pred;
}

// Arbitrary lane-to-lane shuffle (SHFL.IDX)
extern "C" __global__ void __launch_bounds__(32)
probe_shfl_idx(float *out, const float *in) {
    int i = threadIdx.x;
    float val = in[i];

    // Read from arbitrary lane (e.g., broadcast lane 0)
    float from_lane0 = __shfl_sync(0xFFFFFFFF, val, 0);

    // Read from lane (i + 1) % 32 (ring rotation)
    float from_next = __shfl_sync(0xFFFFFFFF, val, (i + 1) % 32);

    // SHFL.UP: shift data up by 1 lane (lane 0 keeps its own value)
    float shifted_up = __shfl_up_sync(0xFFFFFFFF, val, 1);

    out[i] = from_lane0 + from_next + shifted_up;
}

// Ballot + popc pattern (from kernels_box_counting.cu warp-level reduction)
// This is the actual pattern used: ballot -> popc -> lane-0 atomicAdd
extern "C" __global__ void __launch_bounds__(128)
probe_ballot_popc_atomic(unsigned int *global_count,
                         const float *data, float threshold, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int pred = (i < n) ? (data[i] > threshold) : 0;

    // VOTE.BALLOT: which lanes in this warp pass the threshold?
    unsigned int ballot = __ballot_sync(0xFFFFFFFF, pred);

    // Only lane 0 of each warp does the atomic update
    if ((threadIdx.x & 31) == 0) {
        int warp_count = __popc(ballot);
        if (warp_count > 0) {
            atomicAdd(global_count, (unsigned int)warp_count);
        }
    }
}
