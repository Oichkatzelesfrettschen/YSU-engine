# Instant-NGP SASS Kernels — Learning Guide

*For programmers who want to understand GPU optimization. Assumes you know basic programming (variables, loops, functions) but not GPU architecture.*

---

## Table of Contents

1. [Background: How GPUs Execute Code](#background-how-gpus-execute-code)
2. [The NeRF Pipeline](#the-nerf-pipeline)
3. [Kernel 1: Hash Grid Encoding — Deep Dive](#kernel-1-hash-grid-encoding)
4. [Kernel 2: MLP Forward Pass — Deep Dive](#kernel-2-mlp-forward-pass)
5. [Kernel 3: Volume Rendering — Deep Dive](#kernel-3-volume-rendering)
6. [Key Concepts Glossary](#key-concepts-glossary)

---

## Background: How GPUs Execute Code

### CPU vs GPU — The Factory Analogy

A **CPU** is like a factory with 8-16 extremely skilled workers. Each worker can handle any task — complex logic, branching decisions, sequential work — but there are only a few of them.

A **GPU** is like a factory with **thousands** of simple workers. Each one can only do basic math, but there are *so many* of them that they can collectively process massive amounts of data in parallel.

The RTX 4070 Ti Super has **66 SMs** (Streaming Multiprocessors — think of them as departments), each with **128 math units**. That's 8,448 math units running simultaneously.

### Threads, Warps, and Blocks

When you write GPU code (a "kernel"), you launch it with millions of **threads**. Each thread runs the same code but on different data (think: thread 0 processes pixel 0, thread 1 processes pixel 1, etc.).

Threads are grouped:
- **Warp** (32 threads): The hardware *always* executes 32 threads in lockstep. They all run the same instruction at the same time but on different data. This is called **SIMT** (Single Instruction, Multiple Threads).
- **Block** (64-1024 threads): A group of warps that share fast "shared memory" and can synchronize with each other.
- **Grid**: All blocks launched for a kernel.

### The Memory Hierarchy

This is **critical** for understanding our optimizations. GPU memory has multiple levels, each faster but smaller:

```
                Access Time     Size
                ───────────     ────
Registers       ~0 cycles       256 KB per SM (fastest, per-thread)
Shared Memory   ~23 cycles      100 KB per SM (shared within a block)
L1 Cache        ~33 cycles      128 KB per SM (automatic)
L2 Cache        ~200 cycles     48 MB (shared across all SMs)
Global Memory   ~400 cycles     16 GB (VRAM — slowest, largest)
```

The **most common performance bottleneck** is waiting for data from global memory. A single load from L2 takes ~200 cycles — during which the math unit could have done ~200 floating-point operations. Our optimizations focus heavily on hiding this latency.

### What is SASS?

NVIDIA GPUs execute **SASS** (Shader Assembly) instructions. The hierarchy:

```
CUDA C/C++  →  (nvcc compiler)  →  PTX  →  (ptxas assembler)  →  SASS
 (human)                         (virtual)                     (hardware)
```

- **CUDA**: High-level, like regular C++
- **PTX**: An intermediate representation — like a "virtual" assembly language. Each PTX instruction maps to roughly one SASS instruction.
- **SASS**: The actual binary the GPU executes. Instruction opcodes, register numbers, scheduling bits — everything.

We write **inline PTX** inside CUDA code. This gives us control over which instructions are used, while letting the compiler (ptxas) handle register allocation and scheduling.

### Key SASS Instructions We Use

| SASS Instruction | What it does | Latency | Example |
|-----------------|-------------|---------|---------|
| **FFMA** | Fused float multiply-add: `d = a*b + c` | ~4.5 cycles | Dot products, interpolation |
| **LDG.E.64** | Load 64 bits (2 floats) from global memory | ~200 cycles (L2) | Hash table lookups |
| **LDS** | Load from shared memory | ~23 cycles | Weight matrix access |
| **STG** | Store to global memory | ~200 cycles | Writing results |
| **LOP3** | 3-input logic operation (AND, OR, XOR — any combo) | ~4 cycles | Hash function XOR |
| **IMAD** | Integer multiply-add: `d = a*b + c` | ~4 cycles | Address calculation, hashing |
| **MUFU.EX2** | Hardware 2^x approximation (special function unit) | ~6 cycles | Fast exp(), sigmoid |
| **FMNMX** | Float min/max | ~4 cycles | ReLU activation |

---

## The NeRF Pipeline

NeRF (Neural Radiance Fields) turns photographs into 3D scenes. The rendering pipeline has three stages:

```
  3D Point Position (x,y,z)
        │
        ▼
 ┌──────────────────┐
 │ 1. HASH GRID     │  "Encode position into features"
 │    ENCODING       │  Input:  3 floats (x,y,z)
 │                   │  Output: 24 floats (features)
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │ 2. MLP FORWARD   │  "Decode features into color"
 │    (Neural Net)   │  Input:  27 floats (24 features + 3 view dir)
 │                   │  Output: 4 floats (R, G, B, density)
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │ 3. VOLUME        │  "Composite samples into pixel color"
 │    RENDERING      │  Input:  64 samples × (RGBA, dt) per ray
 │                   │  Output: 1 pixel color (RGBA)
 └──────────────────┘
```

For a 512×512 image, that's **262,144 rays**, each sampling ~64 points along the ray. That's **16.7 million** hash grid + MLP evaluations per frame.

---

## Kernel 1: Hash Grid Encoding

### What it does

Given a 3D point (x, y, z), encode it into a 24-dimensional feature vector by looking up learned features at multiple resolution levels.

### The Algorithm (step by step)

For each of 12 resolution levels:

```
1. SCALE:  Multiply (x,y,z) by the level's resolution
           Level 0: ×16,  Level 1: ×24,  Level 2: ×36, ... Level 11: ×1388

2. FLOOR:  Find which grid cell the point falls in
           grid_x = floor(scaled_x)
           grid_y = floor(scaled_y)
           grid_z = floor(scaled_z)

3. FRACT:  How far into the cell? (0.0 to 1.0)
           wx = scaled_x - floor(scaled_x)    ← used for interpolation later

4. HASH:   Find the 8 corners of the cube the point is inside
           For each corner (±1 in x,y,z):
             hash = (corner_x × 73856093) XOR (corner_y × 19349663) XOR (corner_z × 83492791)
             index = hash mod 131072          ← index into hash table

5. LOAD:   Read 2 learned features from hash table for each corner
           8 corners × 2 features = 16 values loaded

6. LERP:   Trilinear interpolation (weighted average based on distance)
           4 lerps on X-axis → 2 lerps on Y-axis → 1 lerp on Z-axis
           Result: 2 features for this level
```

After all 12 levels: 12 × 2 = 24 output features.

### Why it's hard to optimize

This kernel is **memory-bound**. Each level does 8 random lookups into a 12MB hash table. "Random" means the addresses are scattered (not sequential), so the GPU cache can't help much. Each lookup takes ~200 cycles to reach L2 cache.

The compute is cheap (a few multiplies, some XORs, interpolation). The bottleneck is waiting for data.

### Our optimizations explained

**1. float2 vectorized loads (16 × LDG.32 → 8 × LDG.64)**

Each hash table entry has 2 floats. Instead of loading them one at a time:
```
load float[0]     ← 1 instruction, 4 bytes
load float[1]     ← 1 instruction, 4 bytes
```
We load them together:
```
load float2       ← 1 instruction, 8 bytes
```
Same data, half the instructions. The GPU's memory bus naturally handles 64-bit loads at the same throughput as 32-bit loads — you get double the data per instruction for free.

**In SASS**: `LDG.E.64.CONSTANT` instead of two `LDG.E.CONSTANT`

**2. Non-volatile asm (the v1 disaster and fix)**

In v1, we used `asm volatile` on every instruction. The `volatile` keyword tells the compiler: "Don't reorder this instruction — execute it exactly here."

Why that's devastating for memory-bound code:
```
// v1 (volatile): compiler MUST keep this order
load A          ← wait 200 cycles for data
load B          ← wait 200 cycles
XOR             ← 4 cycles
multiply        ← 4 cycles
load C          ← wait 200 more cycles
```

What we want the compiler to do (and what v2-v3 allows):
```
// v2+ (non-volatile): compiler CAN reorder
load A          ← start loading (200 cycles)
load B          ← start loading (200 cycles) — overlaps with A!
load C          ← start loading (200 cycles) — overlaps with A and B!
XOR             ← 4 cycles (fills time while waiting for loads)
multiply        ← 4 cycles (fills time while waiting for loads)
use A           ← by now, A has arrived
use B           ← by now, B has arrived
```

This is called **latency hiding** — doing useful work while waiting for slow memory.

**3. Software pipelining across level pairs**

We process two levels at the same time:
```
Phase 1: Hash + issue loads for Level 0 AND Level 1 (16 loads in flight)
Phase 2: Trilinear interpolation for Level 0 AND Level 1
         (by now, loads from Phase 1 have returned)
```

This doubles the number of outstanding memory requests, giving the memory system more chances to serve data while we compute.

**4. LOP3 — 3-input XOR in one instruction**

The hash function does `a XOR b XOR c`. On older GPUs, that requires two instructions:
```
temp = a XOR b
hash = temp XOR c
```

Ada Lovelace (SM 8.9) has **LOP3** — a single instruction that computes ANY 3-input boolean function. We use truth table `0x96` (which encodes XOR-XOR):
```
hash = LOP3(a, b, c, 0x96)    ← 1 instruction!
```

### The Full Optimization Journey: v1 → v2 → v3

This is the most instructive part of the project — we went from **slower than the compiler** to **11% faster**, and the lessons along the way teach more than the final result.

#### v1: The volatile disaster (0.69x — 31% SLOWER than the compiler)

Our first version wrapped every single inline PTX instruction in `asm volatile(...)`. Here's what that looked like:

```c
// v1: EVERY operation was volatile
asm volatile("lop3.b32 %0, %1, %2, %3, 0x96;" : "=r"(hash) : "r"(a), "r"(b), "r"(c));
asm volatile("ld.global.v2.f32 {%0,%1}, [%2];" : "=f"(f0), "=f"(f1) : "l"(addr));
asm volatile("fma.rn.f32 %0, %1, %2, %3;"     : "=f"(r)    : "f"(w), "f"(a), "f"(b));
```

**Why `volatile` kills memory-bound kernels:**

The GPU can have ~20-30 memory loads in-flight simultaneously per warp. This is how it hides the 200-cycle L2 latency — issue a load, then do something else for 200 cycles, and the data will be ready when you need it (this is called **latency hiding**).

`asm volatile` creates a **scheduling barrier**. The compiler must execute that instruction at that exact point — it cannot move it earlier or later. When every load is volatile, the pipeline collapses:

```
Cycle 0:     load_volatile(A)   ← issue load
Cycle 1-199:  ... 199 cycles of NOTHING (stall!) ...
Cycle 200:   use A
Cycle 201:   load_volatile(B)   ← issue load
Cycle 202-400: ... 199 more cycles of NOTHING ...
Cycle 401:   use B
```

The compiler's version (no volatile) freely reorders:
```
Cycle 0:     load(A)       ← issue (non-blocking)
Cycle 1:     load(B)       ← issue (non-blocking, overlaps with A)
Cycle 2:     load(C)       ← issue (non-blocking, overlaps with A and B)
Cycle 3-6:   XOR, IMAD...  ← do math while all 3 loads are in flight
...
Cycle ~200:  use A          ← data arrived!
Cycle ~201:  use B          ← also arrived!
```

**We serialized what should have been parallel.** The GPU was idle 95% of the time.

#### v2: Removing the barriers (1.03x — back to parity)

The fix was conceptually simple but required rethinking our approach:

| Component | v1 (broken) | v2 (fixed) | Why |
|-----------|-------------|------------|-----|
| Hash XOR | `asm volatile("lop3...")` | `asm("lop3...")` | Non-volatile: compiler CAN reorder |
| Trilinear interp | `asm volatile("fma...")` | `a + t*(b-a)` (C code) | Compiler generates FMA, full optimization freedom |
| Feature loads | `asm volatile("ld.global...")` | `__ldg()` intrinsic | Compiler knows it's a load, schedules optimally |
| Feature stores | `asm volatile("st.global...")` | `output[i] = val` (C) | Compiler handles store scheduling |

Key insight: **non-volatile `asm` still guarantees the instruction is emitted** (compiler won't delete it), but lets the compiler freely reorder it relative to other instructions. This is the sweet spot — you get your custom instruction AND the compiler's scheduler.

We kept `asm("lop3...")` for the 3-input XOR because C has no equivalent (two C XORs = 2 SASS instructions vs LOP3 = 1). Everything else went back to C or intrinsics.

Result: 1.03x — we'd undone the self-inflicted damage and caught up to the compiler.

#### v3: Beating the compiler (1.11x)

Two optimizations pushed us past:

**Optimization 1: float2 vectorized loads**

Each hash table entry is 2 floats (8 bytes). The compiler loaded them as two separate 32-bit loads:
```
// Compiler generates:
LDG.E.CONSTANT R22, [R4.64]        // 1st float, 4 bytes
LDG.E.CONSTANT R26, [R4.64+0x4]    // 2nd float, 4 bytes
```

We forced a single 64-bit load:
```c
float2 v = __ldg((const float2*)(level_ptr + hash_index * 2));
// Compiles to:
// LDG.E.64.CONSTANT R22, [R22.64]    // both floats, 8 bytes, 1 instruction
```

Same data, half the instructions. The memory bus handles 64-bit loads at the same throughput — you get twice the data per instruction.

**Across the whole kernel**: 96 loads instead of ~192. That's 96 fewer instructions for decode/issue/retire.

**Optimization 2: Software pipelining across level pairs**

Instead of processing one level at a time, we interleave two:
```
// Process levels in pairs: (0,1), (2,3), (4,5), (6,7), (8,9), (10,11)
for (pair = 0; pair < 6; pair++) {
    // Issue 16 loads simultaneously (8 for level A + 8 for level B)
    hash_and_load(level_A);
    hash_and_load(level_B);
    
    // The hash computation for level B = ~100 cycles of ALU work
    // By now, level A's loads (issued first) have had time to arrive
    
    // Trilinear interpolation for both
    trilinear(level_A);   // loads arrived ~200 cycles ago
    trilinear(level_B);   // loads arrived ~100 cycles ago
}
```

16 simultaneous memory requests (vs 8) means the memory controller has more work to pipeline. And the ALU work for level B's hash computation acts as free latency hiding for level A's loads.

#### The scoreboard

| Version | Speedup | Key Change | SASS Signature |
|---------|---------|------------|----------------|
| **v1** | **0.69x** | All `asm volatile` → serialized loads | Interleaving destroyed |
| **v2** | **1.03x** | Non-volatile asm + C trilinear + `__ldg()` | Load reordering restored |
| **v3** | **1.11x** | float2 loads + level-pair pipelining at `-O2` | 96 × LDG.E.64.CONSTANT |
| *ref* | *1.00x* | Compiler's auto-generated code | ~192 × LDG.E.32 |

**The lesson**: For memory-bound kernels, the compiler's instruction scheduler is your *ally*, not your enemy. Use inline asm surgically (for instructions C can't express), and let the compiler handle the rest.

---

## Kernel 2: MLP Forward Pass

### What it does

A tiny fully-connected neural network:
```
Input (27 values) → Layer 0 (64 neurons, ReLU) → Layer 1 (64 neurons, ReLU) → Output (4 values, sigmoid)
```

Each layer computes: `output = activation(weight_matrix × input + bias)`

### The math

For one neuron in Layer 0, the computation is a **dot product** of 27 inputs with 27 weights, plus a bias:

```
result = bias + w0*x0 + w1*x1 + w2*x2 + ... + w26*x26
```

That's 27 multiply-adds for one neuron. Layer 0 has 64 neurons → 64 × 27 = **1,728 multiply-adds**.
Layer 1: 64 × 64 = **4,096 multiply-adds**.
Output: 4 × 64 = **256 multiply-adds**.

Total: ~6,080 multiply-adds per sample. At 262K samples, that's 1.6 billion operations.

### Why this kernel is fast (3.16x speedup)

This kernel is **compute-bound** — the bottleneck is raw math throughput, not memory. That's where manual optimization shines.

**1. 8-wide ILP (Instruction Level Parallelism)**

The GPU's FFMA unit has a 4.5-cycle latency. If you do one multiply-add at a time, you waste 3.5 cycles waiting between each one:

```
// Naive: 1 accumulator (serial dependency chain)
acc += w0 * x0       ← 4.5 cycles (then wait...)
acc += w1 * x1       ← 4.5 cycles (then wait...)
acc += w2 * x2       ← 4.5 cycles (then wait...)
// Throughput: 1 FFMA per 4.5 cycles
```

Instead, we compute 8 neurons simultaneously with 8 independent accumulators:

```
// Our approach: 8 independent accumulators
acc[0] += w0_0 * x0     ← cycle 0
acc[1] += w0_1 * x0     ← cycle 1 (doesn't depend on acc[0]!)
acc[2] += w0_2 * x0     ← cycle 2
acc[3] += w0_3 * x0     ← cycle 3
acc[4] += w0_4 * x0     ← cycle 4
acc[5] += w0_5 * x0     ← cycle 5 (acc[0] result ready by now!)
acc[6] += w0_6 * x0     ← cycle 6
acc[7] += w0_7 * x0     ← cycle 7
acc[0] += w1_0 * x1     ← cycle 8 (no stall! acc[0] was ready at cycle 5)
// Throughput: 1 FFMA per cycle — fully pipelined!
```

The compiler *could* theoretically do this but doesn't — it's conservative about register usage and instruction reordering. We manually force it.

**In SASS**: The kernel generates 6,249 FFMA instructions — nearly everything is fused multiply-add.

**2. Shared memory weight tiling**

The weight matrix (6,212 floats = ~24 KB) is loaded into **shared memory** at the start of each block. Shared memory is ~8.7x faster than global memory (23 vs 200 cycles).

All 128 threads in a block cooperatively load the weights, then everyone reads from shared memory during computation:
```
// Cooperative loading (all threads work together)
for (int i = threadIdx; i < weight_count; i += block_size)
    shared_weights[i] = global_weights[i];
__syncthreads();  // wait for everyone to finish

// Now all 128 threads read from fast shared memory
for (int j = 0; j < 27; j++)
    acc += shared_weights[neuron][j] * input[j];  // LDS.32 (~23 cycles)
```

**In SASS**: 1,553 LDS (shared memory loads) instead of global memory loads.

**3. FMNMX ReLU — one instruction instead of a branch**

ReLU is `max(x, 0)`. A naive if/else:
```
if (x > 0) result = x;
else result = 0;
```
That's a branch, which causes thread divergence on a GPU (some threads in the warp go one way, others go another — both paths execute serially).

Our approach — single instruction, no branch:
```asm
FMNMX result, x, RZ, !PT    // max(x, 0) — RZ is the zero register
```

**In SASS**: 130 FMNMX instructions (64 neurons × 2 layers + 2 extras).

**4. MUFU.EX2 fast sigmoid**

The output layer uses sigmoid: `1 / (1 + exp(-x))`. Standard exp() implementation is ~30 instructions.

We rewrite it using the hardware's fast 2^x unit (MUFU.EX2):
```
sigmoid(x) = 1 / (1 + 2^(-x × log2(e)))
```

That's: 1 FMUL + 1 MUFU.EX2 + 1 FADD + 1 MUFU.RCP = **4 instructions** total.

**In SASS**: 14 MUFU instructions across the kernel.

### Results

**3.16x speedup** over the reference CUDA kernel, with max error of only 1.19 × 10^-7 (effectively identical results — the tiny error comes from MUFU.EX2 being an approximation).

---

## Kernel 3: Volume Rendering

### What it does

For each ray (one per pixel), combine all the samples along the ray into one final pixel color. This is **alpha compositing**, the same technique used in video games, Photoshop layers, and movie VFX.

### The algorithm

```python
transmittance = 1.0    # starts fully transparent (light passes through)
color = (0, 0, 0)      # starts black

for each sample along the ray:
    alpha = 1 - exp(-density * step_size)          # how opaque is this sample?
    weight = transmittance * alpha                  # how much does it contribute?
    color += weight * sample_color                  # add weighted color
    transmittance *= (1 - alpha)                    # reduce light passing through
    
    if transmittance < 0.001:                       # already opaque?
        break                                       # stop — nothing behind matters
```

### Our optimizations explained

**1. MUFU.EX2 fast exponential (2 instructions instead of ~20)**

The `exp(-x)` computation is the inner-loop bottleneck. We rewrite it as:
```
exp(-x) = 2^(-x × log2(e))
```
And use the GPU's hardware exponent unit:
```asm
FMUL    neg_xl2e, x, -1.4427    // multiply by -log2(e)
MUFU.EX2 result, neg_xl2e       // hardware 2^x (built-in approximation)
```

Two instructions, ~8 cycles. The standard library `expf()` compiles to ~20+ instructions.

**2. Reusing the exponential result**

Notice: `(1 - alpha) = exp(-sigma * dt)`, which we already computed for alpha!
```
neg_exp = exp(-sigma * dt)
alpha   = 1 - neg_exp
...
transmittance *= neg_exp    // reuse! instead of computing (1 - alpha) again
```

This eliminates a subtraction in the hot loop.

**3. Predicated early exit**

When transmittance drops below 0.001, further samples contribute < 0.1% to the pixel. We stop:
```asm
FSETP.LT  P0, _, transmittance, 0.001  // set predicate if T < threshold
SELP      done, 1, 0, P0               // convert to integer boolean
// then check 'done' and break
```

This is done without divergent branches — the predicate register is set and read without a branch instruction.

**4. Vectorized load/store**

Input RGBA is loaded as `float4` (128-bit, one instruction) and output is stored the same way:
```asm
LDG.E.128  {r, g, b, sigma}, [ptr]    // load 4 floats at once
STG.E.128  [out], {r, g, b, alpha}    // store 4 floats at once
```

### Results

**1.53x speedup**, max error 2.98 × 10^-7 (from MUFU.EX2 approximation error accumulating over 64 steps — still visually identical).

---

## Key Concepts Glossary

| Term | Meaning |
|------|---------|
| **SASS** | The GPU's native binary instruction set (like x86 for CPUs) |
| **PTX** | An intermediate assembly language that maps ~1:1 to SASS |
| **Kernel** | A function that runs on the GPU across thousands of threads |
| **Thread** | One worker executing the kernel code on one piece of data |
| **Warp** | 32 threads that execute in lockstep (always together) |
| **Block** | A group of warps (64-1024 threads) that share fast memory |
| **SM** | Streaming Multiprocessor — one "department" of the GPU |
| **FFMA** | Fused Float Multiply-Add: `d = a*b + c` in one instruction |
| **LDG** | Load from Global memory (slow, ~200 cycles) |
| **LDS** | Load from Shared memory (fast, ~23 cycles) |
| **MUFU** | Multi-Function Unit — hardware exp, log, sin, cos, reciprocal |
| **LOP3** | 3-input Logic Operation — any boolean combo in 1 instruction |
| **ILP** | Instruction Level Parallelism — keeping the pipeline full |
| **Latency hiding** | Doing useful work while waiting for slow memory |
| **Register** | Fastest storage — each thread has its own (0 cycle access) |
| **Shared memory** | Fast storage shared by all threads in a block (23 cycles) |
| **Global memory** | GPU VRAM — large but slow (200-400 cycles) |
| **Compute-bound** | Limited by math speed (like MLP: lots of FFMA) |
| **Memory-bound** | Limited by data transfer speed (like hash grid: lots of LDG) |
| **asm volatile** | Tells compiler "do NOT reorder this instruction" |
| **Software pipelining** | Starting the next batch of work before finishing current |
| **Trilinear interpolation** | Weighted average across 8 corners of a 3D cube |
| **Hash table** | Array where the index is computed by a hash function |
| **Alpha compositing** | Blending colors front-to-back with opacity |
| **Sigmoid** | S-shaped function that maps any value to 0-1 range |
| **ReLU** | `max(x, 0)` — sets negative values to zero |
| **Neural network** | Layers of multiply-add + activation (learned from data) |

---

## Further Reading

- **NVIDIA PTX ISA docs**: Search "PTX ISA 8.x" — the official reference for every PTX instruction
- **CUDA C Programming Guide**: Chapter on shared memory and occupancy
- **Instant-NGP paper**: "Instant Neural Graphics Primitives with a Multiresolution Hash Encoding" (Muller et al., 2022)
- **NeRF paper**: "NeRF: Representing Scenes as Neural Radiance Fields" (Mildenhall et al., 2020)

---

*Built by Umut Korkmaz. RTX 4070 Ti Super, CUDA 13.1, March 2026.*
