/*
 * SASS RE Probe: Barriers Under Divergent Control Flow
 * Isolates: BSSY/BSYNC reconvergence barriers with complex nesting
 *
 * Ada uses BSSY (barrier set synchronize) and BSYNC (barrier synchronize)
 * for warp reconvergence after divergent branches. This probe creates
 * pathological divergence patterns to maximize BSSY/BSYNC emission.
 */

// Deeply nested if/else (4 levels -> 4 BSSY/BSYNC pairs)
extern "C" __global__ void __launch_bounds__(32)
probe_diverge_depth4(float *out, const float *in) {
    int i = threadIdx.x;
    float v = in[i];
    if (i < 16) {                    // BSSY level 1
        if (i < 8) {                 // BSSY level 2
            if (i < 4) {             // BSSY level 3
                if (i < 2) {         // BSSY level 4
                    v = v * 16.0f;
                } else {
                    v = v * 15.0f;
                }                     // BSYNC level 4
                v += 1.0f;
            } else {
                v = v * 14.0f;
            }                         // BSYNC level 3
        } else {
            if (i < 12) {
                v = v * 13.0f;
            } else {
                v = v * 12.0f;
            }
        }                             // BSYNC level 2
    } else {
        if (i < 24) {
            v = v * 11.0f;
        } else {
            v = v * 10.0f;
        }
    }                                 // BSYNC level 1
    out[i] = v;
}

// Switch with 8 cases (generates BMOV barrier token management)
extern "C" __global__ void __launch_bounds__(32)
probe_diverge_switch8(float *out, const float *in) {
    int i = threadIdx.x;
    float v = in[i];
    switch (i % 8) {
    case 0: v = v * 2.0f + 1.0f; break;
    case 1: v = v * 3.0f + 2.0f; break;
    case 2: v = v * 4.0f + 3.0f; break;
    case 3: v = v * 5.0f + 4.0f; break;
    case 4: v = v * 6.0f + 5.0f; break;
    case 5: v = v * 7.0f + 6.0f; break;
    case 6: v = v * 8.0f + 7.0f; break;
    case 7: v = v * 9.0f + 8.0f; break;
    }
    out[i] = v;
}

// Loop with per-thread iteration count (divergent loop exit)
extern "C" __global__ void __launch_bounds__(32)
probe_diverge_variable_loop(float *out, const float *in) {
    int i = threadIdx.x;
    float v = in[i];
    int iters = (i % 8) + 1;  // 1-8 iterations per thread
    for (int j = 0; j < iters; j++) {
        v = v * 0.9f + 0.1f;
    }
    out[i] = v;
}

// Nested loops with breaks (BREAK + BSSY/BSYNC interaction)
extern "C" __global__ void __launch_bounds__(32)
probe_diverge_nested_break(float *out, const float *in, float threshold) {
    int i = threadIdx.x;
    float v = in[i];
    float acc = 0.0f;
    for (int outer = 0; outer < 4; outer++) {
        for (int inner = 0; inner < 8; inner++) {
            acc += v;
            if (acc > threshold * (float)(i + 1)) {
                break;  // BREAK from inner loop (per-thread divergent exit)
            }
            v *= 0.95f;
        }
        if (acc > threshold * 10.0f) break;  // BREAK from outer loop
    }
    out[i] = acc;
}

// Warp divergence with reconvergence at different points
extern "C" __global__ void __launch_bounds__(32)
probe_diverge_asymmetric(float *out, const float *in) {
    int i = threadIdx.x;
    float v = in[i];

    if (i < 1) {
        // Only lane 0: long computation path
        for (int j = 0; j < 100; j++) v = v * 0.99f + 0.01f;
    } else if (i < 16) {
        // Lanes 1-15: medium path
        for (int j = 0; j < 10; j++) v = v * 0.9f + 0.1f;
    } else {
        // Lanes 16-31: short path
        v = v * 2.0f;
    }
    // All lanes reconverge here (BSYNC with significant imbalance)
    out[i] = v;
}
