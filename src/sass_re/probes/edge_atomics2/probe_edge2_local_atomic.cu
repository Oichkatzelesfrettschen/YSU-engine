/*
 * SASS RE Probe: Local Memory Atomics + CPU-Visible Memory
 * Isolates: STL/LDL patterns, managed memory atomics, mapped memory
 *
 * "Local atomics" don't exist as hardware instructions -- local memory
 * (LMEM) is per-thread and doesn't need atomics. But we can test:
 *   1. Atomic operations on mapped (zero-copy) host memory
 *   2. Atomic operations on managed (unified) memory
 *   3. Atomic operations with system-scope fences
 *   4. CPU-visible stores via STG.E.STRONG.SYS
 */

// System-scope atomic on global memory (visible to CPU)
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_atomic(volatile int *sys_counter) {
    // System-scope atomicAdd: visible to CPU immediately
    atomicAdd_system((int*)sys_counter, 1);
    __threadfence_system(); // MEMBAR.SC.SYS
}

// System-scope CAS on global memory
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_cas(volatile int *lock, volatile int *data) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if (tid == 0) {
        // System-scope CAS: try to acquire lock visible to CPU
        while (atomicCAS_system((int*)lock, 0, 1) != 0);
        data[0] = data[0] + 1;
        __threadfence_system();
        atomicExch_system((int*)lock, 0);
    }
}

// System-scope 64-bit atomic
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_atomic64(volatile unsigned long long *counter) {
    atomicAdd_system((unsigned long long*)counter, 1ULL);
    __threadfence_system();
}

// System-scope float atomic (promotes to FP32 atomicAdd with SYS scope)
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_float_atomic(volatile float *counter) {
    // This may generate ATOM.E.ADD.F32.*.STRONG.SYS
    atomicAdd_system((float*)counter, 1.0f);
    __threadfence_system();
}

// Store with system scope (CPU-visible write without atomic)
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_store(volatile int *data, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    // System-scope store sequence: write + system fence
    data[i] = i;
    __threadfence_system();
}

// Load with system scope (read CPU-written data)
extern "C" __global__ void __launch_bounds__(128)
edge2_sys_load(int *out, volatile const int *cpu_data, int n) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n) return;
    __threadfence_system(); // Ensure CPU writes are visible
    out[i] = cpu_data[i];
}

// System-scope release-acquire pattern (producer-consumer with CPU)
extern "C" __global__ void __launch_bounds__(128)
edge2_release_acquire(volatile int *flag, volatile int *data, int value) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    if (tid == 0) {
        // Release: store data then set flag (with system fence between)
        data[0] = value;
        __threadfence_system();
        atomicExch_system((int*)flag, 1);
    }
}
