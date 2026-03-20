/*
 * SASS RE Probe: Dependency Barriers and Scoreboard Management
 * Isolates: DEPBAR, scoreboard stalls, instruction scheduling barriers
 *
 * Ada uses a dependency tracking system via scoreboards. DEPBAR.LE waits
 * until outstanding memory operations drop below a threshold. This is
 * used by the compiler to manage memory-compute ordering without full
 * __syncthreads.
 *
 * Also probes: instruction-level dependencies, read-after-write hazards,
 * and how the compiler inserts scheduling barriers.
 */

// Long memory dependency chain (forces DEPBAR for LDG ordering)
extern "C" __global__ void __launch_bounds__(128)
probe_depbar_ldg_chain(float *out, const float *in, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    // Chain of dependent loads: each load depends on previous result
    float v = in[i];
    int idx = (int)(v * 100.0f) % n;
    v = in[idx];
    idx = (int)(v * 100.0f) % n;
    v = in[idx];
    idx = (int)(v * 100.0f) % n;
    v = in[idx];
    idx = (int)(v * 100.0f) % n;
    v = in[idx];
    out[i] = v;
}

// Mixed load-store with explicit fences between phases
extern "C" __global__ void __launch_bounds__(128)
probe_depbar_load_store_phases(float *out, const float *in, int n) {
    __shared__ float s[256];
    int tid = threadIdx.x;

    // Phase 1: all loads
    float a = in[tid];
    float b = in[tid + 128];
    float c = in[tid + 256];
    float d = in[tid + 384];

    // Phase 2: shared memory stores (compiler inserts DEPBAR here)
    s[tid] = a + b;
    s[tid + 128] = c + d;
    __syncthreads();

    // Phase 3: shared memory loads
    float e = s[255 - tid];
    float f = s[127 - (tid % 128)];

    // Phase 4: global stores
    out[tid] = e + f;
    out[tid + 128] = e * f;
}

// Scoreboard saturation: many outstanding loads (should trigger DEPBAR.LE)
extern "C" __global__ void __launch_bounds__(128)
probe_depbar_many_outstanding(float *out, const float *in, int stride) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    // Issue 32 independent loads to saturate the scoreboard
    float v0  = in[tid];
    float v1  = in[tid + stride];
    float v2  = in[tid + stride * 2];
    float v3  = in[tid + stride * 3];
    float v4  = in[tid + stride * 4];
    float v5  = in[tid + stride * 5];
    float v6  = in[tid + stride * 6];
    float v7  = in[tid + stride * 7];
    float v8  = in[tid + stride * 8];
    float v9  = in[tid + stride * 9];
    float v10 = in[tid + stride * 10];
    float v11 = in[tid + stride * 11];
    float v12 = in[tid + stride * 12];
    float v13 = in[tid + stride * 13];
    float v14 = in[tid + stride * 14];
    float v15 = in[tid + stride * 15];
    // Compute requires all loads to have completed (DEPBAR.LE 0)
    out[tid] = v0+v1+v2+v3+v4+v5+v6+v7+v8+v9+v10+v11+v12+v13+v14+v15;
}

// Write-after-read hazard (should show scoreboard management in SASS)
extern "C" __global__ void __launch_bounds__(128)
probe_depbar_war_hazard(float *data, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    float v = data[i];     // Read
    v = v * 2.0f + 1.0f;   // Compute
    data[i] = v;           // Write-after-read to same address
}
