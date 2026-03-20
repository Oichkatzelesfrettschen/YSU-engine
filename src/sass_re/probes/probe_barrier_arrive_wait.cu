/*
 * SASS RE Probe: Split-Phase Barriers (arrive/wait pattern)
 * Isolates: BAR.ARRIVE + BAR.SYNC split-phase for pipeline overlap
 *
 * Split-phase barriers allow threads to signal arrival (non-blocking)
 * then continue with independent work before waiting. This enables
 * overlapping compute with barrier propagation latency.
 */

// Classic producer-consumer with split barrier
extern "C" __global__ void __launch_bounds__(256)
probe_arrive_wait_producer_consumer(float *out, const float *in, int n) {
    __shared__ float buf[256];
    int tid = threadIdx.x;

    // Phase 1: producers load data
    if (tid < 128) {
        buf[tid] = in[tid + blockIdx.x * 256];
        buf[tid + 128] = in[tid + 128 + blockIdx.x * 256];
        // Signal: production complete
        asm volatile("bar.arrive 0, 256;");
    }

    // Phase 2: consumers wait then process
    if (tid >= 128) {
        asm volatile("bar.sync 0, 256;");
        out[tid + blockIdx.x * 256] = buf[tid] * 2.0f;
    } else {
        // Producers also wait before next phase
        asm volatile("bar.sync 0, 256;");
        out[tid + blockIdx.x * 256] = buf[tid];
    }
}

// Multi-stage pipeline with arrive/wait
extern "C" __global__ void __launch_bounds__(256)
probe_arrive_wait_pipeline(float *out, const float *in, int stages) {
    __shared__ float ping[256], pong[256];
    int tid = threadIdx.x;

    // Load first stage
    ping[tid] = in[tid + blockIdx.x * 256];
    asm volatile("bar.arrive 1, 256;");

    for (int s = 1; s < stages; s++) {
        float *src = (s & 1) ? pong : ping;
        float *dst = (s & 1) ? ping : pong;

        // Arrive at next stage barrier
        asm volatile("bar.sync 1, 256;");

        // Load next + compute current
        dst[tid] = in[s * 256 + tid + blockIdx.x * 256 * stages];
        float result = src[tid] * 0.5f + src[(tid + 1) % 256] * 0.25f + src[(tid + 255) % 256] * 0.25f;
        out[(s-1) * 256 + tid + blockIdx.x * 256 * stages] = result;

        asm volatile("bar.arrive 1, 256;");
    }

    // Final stage
    asm volatile("bar.sync 1, 256;");
    float *last = (stages & 1) ? ping : pong;
    out[(stages-1) * 256 + tid + blockIdx.x * 256 * stages] = last[tid];
}
