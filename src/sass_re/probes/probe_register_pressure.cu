/*
 * SASS RE Probe: Register Pressure and Spill Characterization
 * Isolates: How register count affects occupancy and spill behavior
 *
 * Ada Lovelace SM 8.9 register file: 65,536 registers per SM (256 KB).
 * Registers are allocated in 8-register granularity.
 *
 * Occupancy model:
 *   128 regs/thread * 128 threads/block = 16,384 regs/block
 *   65,536 / 16,384 = 4 blocks/SM max
 *   With shared memory constraints, typically 2-4 blocks/SM.
 *
 * When a kernel exceeds the register budget, ptxas spills registers to
 * local memory (LMEM). LMEM routes through L1 -> L2 -> DRAM with ~92
 * cycle latency (same as global memory). For MRT kernels (~128 regs),
 * this is the primary performance risk.
 *
 * This probe creates kernels with controlled register pressure to observe:
 *   - STL (store local) / LDL (load local) for spills
 *   - The threshold at which spilling begins
 *   - Impact of __launch_bounds__ on register allocation
 *
 * Key SASS instructions:
 *   STL    -- store to local memory (register spill)
 *   LDL    -- load from local memory (register reload)
 *   LDL.LU -- local memory load with uniform hint
 */

// Low register pressure: 16 regs (well within budget)
extern "C" __global__ void __launch_bounds__(256, 4)
probe_reg_low(float *out, const float *in) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    float a = in[i];
    float b = a * 0.5f;
    float c = b + 1.0f;
    out[i] = c;
}

// Medium register pressure: ~64 regs (D3Q19 BGK pattern)
// Holds 19 distribution values + macroscopic fields in registers
extern "C" __global__ void __launch_bounds__(128, 4)
probe_reg_medium(float *out, const float *in, int n_cells) {
    int cell = threadIdx.x + blockIdx.x * blockDim.x;
    if (cell >= n_cells) return;

    // Load 19 distributions into registers (simulates D3Q19)
    float f[19];
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        f[d] = in[d * n_cells + cell];
    }

    // Compute macroscopic: rho, ux, uy, uz
    float rho = 0.0f;
    float ux = 0.0f, uy = 0.0f, uz = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        rho += f[d];
    }
    // Simplified momentum (just sum alternating for register pressure)
    ux = f[1] - f[2] + f[7] - f[8] + f[9] - f[10] + f[11] - f[12];
    uy = f[3] - f[4] + f[7] - f[8] + f[13] - f[14] + f[15] - f[16];
    uz = f[5] - f[6] + f[9] - f[10] + f[13] - f[14] + f[17] - f[18];

    out[cell] = rho + ux + uy + uz;
}

// High register pressure: ~128 regs (D3Q19 MRT collision)
// Should approach or exceed the spill threshold
extern "C" __global__ void __launch_bounds__(128, 2)
probe_reg_high(float *out, const float *in, float tau, int n_cells) {
    int cell = threadIdx.x + blockIdx.x * blockDim.x;
    if (cell >= n_cells) return;

    float f[19];
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        f[d] = in[d * n_cells + cell];
    }

    // Macroscopic
    float rho = 0.0f;
    float ux = 0.0f, uy = 0.0f, uz = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) rho += f[d];
    ux = f[1] - f[2] + f[7] - f[8] + f[9] - f[10] + f[11] - f[12];
    uy = f[3] - f[4] + f[7] - f[8] + f[13] - f[14] + f[15] - f[16];
    uz = f[5] - f[6] + f[9] - f[10] + f[13] - f[14] + f[17] - f[18];
    float inv_rho = 1.0f / rho;
    ux *= inv_rho; uy *= inv_rho; uz *= inv_rho;

    // MRT moment transform (19 moments from 19 distributions)
    // This is a dense 19x19 matrix multiply that demands ~128 registers
    float m[19];
    m[0]  = rho;
    m[1]  = -30.0f*f[0] - 11.0f*(f[1]+f[2]+f[3]+f[4]+f[5]+f[6]) + 8.0f*(f[7]+f[8]+f[9]+f[10]+f[11]+f[12]+f[13]+f[14]+f[15]+f[16]+f[17]+f[18]);
    m[2]  = 12.0f*f[0] - 4.0f*(f[1]+f[2]+f[3]+f[4]+f[5]+f[6]) + (f[7]+f[8]+f[9]+f[10]+f[11]+f[12]+f[13]+f[14]+f[15]+f[16]+f[17]+f[18]);
    m[3]  = ux * rho;
    m[4]  = -4.0f*(f[1]-f[2]) + (f[7]-f[8]+f[9]-f[10]+f[11]-f[12]);
    m[5]  = uy * rho;
    m[6]  = -4.0f*(f[3]-f[4]) + (f[7]-f[8]+f[13]-f[14]+f[15]-f[16]);
    m[7]  = uz * rho;
    m[8]  = -4.0f*(f[5]-f[6]) + (f[9]-f[10]+f[13]-f[14]+f[17]-f[18]);
    m[9]  = 2.0f*(f[1]+f[2]) - (f[3]+f[4]) - (f[5]+f[6]) + (f[7]+f[8]+f[9]+f[10]+f[11]+f[12]) - (f[13]+f[14]+f[15]+f[16]+f[17]+f[18]);
    m[10] = -4.0f*(f[1]+f[2]) + 2.0f*(f[3]+f[4]+f[5]+f[6]) + (f[7]+f[8]+f[9]+f[10]+f[11]+f[12]) - (f[13]+f[14]+f[15]+f[16]+f[17]+f[18]);
    m[11] = (f[3]+f[4]) - (f[5]+f[6]) + (f[7]+f[8]) - (f[9]+f[10]) - (f[11]+f[12]) + (f[13]+f[14]) - (f[15]+f[16]) + (f[17]+f[18]);
    m[12] = -2.0f*((f[3]+f[4])-(f[5]+f[6])) + (f[7]+f[8]) - (f[9]+f[10]) - (f[11]+f[12]) + (f[13]+f[14]) - (f[15]+f[16]) + (f[17]+f[18]);
    m[13] = (f[7]-f[8]) - (f[9]+f[10]) + (f[11]+f[12]) - (f[13]+f[14]);  // pxy placeholder
    m[14] = (f[7]-f[8]) + (f[9]-f[10]) - (f[11]-f[12]) - (f[13]-f[14]);  // pxz placeholder
    m[15] = (f[7]-f[8]) - (f[11]-f[12]) + (f[15]-f[16]) - (f[17]-f[18]); // pyz placeholder
    m[16] = f[7] - f[8] + f[9] - f[10] - f[11] + f[12] - f[13] + f[14]; // ghost 1
    m[17] = f[7] - f[8] - f[9] + f[10] + f[15] - f[16] - f[17] + f[18]; // ghost 2
    m[18] = f[11] - f[12] - f[13] + f[14] + f[15] - f[16] + f[17] - f[18]; // ghost 3

    // Relaxation (simplified: just use tau for all rates)
    float inv_tau = 1.0f / tau;
    float usq = ux*ux + uy*uy + uz*uz;
    // Relax moments toward equilibrium (simplified)
    m[1] -= inv_tau * (m[1] - (-11.0f*rho + 19.0f*rho*usq));
    m[9] -= inv_tau * (m[9] - rho*(2.0f*ux*ux - uy*uy - uz*uz));

    // Sum moments for output (prevents dead-code elimination)
    float sum = 0.0f;
    #pragma unroll
    for (int k = 0; k < 19; k++) sum += m[k];

    out[cell] = sum;
}

// Extreme register pressure: 2x D3Q19 state (coarsened kernel pattern)
// Two cells per thread, each with 19 distributions = 38 live arrays
extern "C" __global__ void __launch_bounds__(128, 1)
probe_reg_extreme(float *out, const float *in, int n_cells) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    int cell_a = tid * 2;
    int cell_b = tid * 2 + 1;
    if (cell_b >= n_cells) return;

    // Two independent D3Q19 states in registers simultaneously
    float fa[19], fb[19];
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        fa[d] = in[d * n_cells + cell_a];
        fb[d] = in[d * n_cells + cell_b];
    }

    float rho_a = 0.0f, rho_b = 0.0f;
    #pragma unroll
    for (int d = 0; d < 19; d++) {
        rho_a += fa[d];
        rho_b += fb[d];
    }

    out[cell_a] = rho_a;
    out[cell_b] = rho_b;
}
