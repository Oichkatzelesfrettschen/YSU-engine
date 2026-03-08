# Instant-NGP Hot Loops in SASS-Level PTX

Hand-written SASS-level implementations of the three critical kernels in
NVIDIA's [Instant Neural Graphics Primitives](https://nvlabs.github.io/instant-ngp/).
Written in inline PTX assembly for Ada Lovelace (SM 8.9) with every instruction
hand-chosen to match the optimal SASS output.

## Why inline PTX instead of raw SASS?

There is no official NVIDIA SASS assembler. Community tools (CuAssembler, MaxAs)
have limited SM 8.9 support. Inline PTX gives us:
- **1:1 mapping** to SASS instructions (ptxas translates each PTX op to exactly one SASS op)
- **Full control** over register allocation, instruction selection, and data movement
- **Compilable** with standard nvcc — no binary patching needed
- **Verifiable** — we disassemble the output and confirm every instruction matches intent

## Kernels

### 1. Hash Grid Encoding (`hashgrid_encode.cu`)
The signature kernel of instant-NGP. For each 3D point:
- Compute grid coordinates at L resolution levels (12–16 levels)
- Hash 8 voxel corners per level using spatial hash (prime XOR)
- Load 2 features per corner from hash table (16 loads per level)
- Trilinear interpolation → 2L output features

**SASS-level optimizations (v3):**
- **float2 vectorized loads**: 8× LDG.E.64 per level instead of 16× LDG.E.32 — halves load instruction count. Compiler generates scalar loads for the reference.
- **Software pipelining across level pairs**: issues loads for level N+1 while computing trilinear for level N, keeping 16 LDG.E.64 in-flight simultaneously
- **LOP3.LUT 0x96** for 3-input XOR in a single instruction (1 LOP3 vs 2 XOR for ref)
- **Non-volatile asm + pure C trilinear**: gives ptxas full scheduling freedom to interleave loads with compute
- **`__ldg()` intrinsic**: cache-through hint for L1/L2, generates LDG.E.64.CONSTANT
- FFMA chains for trilinear interpolation, register-resident features (no spills)

**Optimization history:**
- v1 (asm volatile everywhere): 0.69x — volatile barriers prevented load/compute interleaving
- v2 (non-volatile asm + C trilinear): 1.03x — eliminated regression, at parity
- v3 (float2 + SW pipelining + -O2): **1.11x** — real win from vectorized loads

### 2. Tiny MLP Forward (`mlp_forward.cu`)
64-wide fully-connected network: 27→64→64→4 with ReLU.

**SASS-level optimizations:**
- FFMA dot-product chains with 8-wide ILP (8 independent accumulators)
- MUFU.EX2 for fast sigmoid approximation
- Predicated ReLU via FMNMX (no branch, no predicate register)
- Shared memory weight tiling for the 64×64 hidden layer
- Register blocking: 4×4 output tile per thread

### 3. Volume Rendering (`volume_render.cu`)
Front-to-back alpha compositing along each ray.

**SASS-level optimizations:**
- Early ray termination via predicated exit (ISETP + @P BRA)
- FFMA for T*(1-alpha) accumulation
- MUFU.RCP for 1/(1+exp(-sigma*dt)) (fast sigmoid of density)
- Warp-level ray coherence: SHFL for neighbor sample sharing

## Build & Verify

```powershell
cd src/sass_re/instant_ngp

# One-click: compile, disassemble, validate, benchmark:
powershell -ExecutionPolicy Bypass -File build_and_verify.ps1

# Or manually:
# 1. Compile (use -O2 for best ptxas scheduling)
nvcc -arch=sm_89 -O2 -allow-unsupported-compiler -lineinfo ^
     -o build/ngp_validate.exe ^
     hashgrid_encode.cu mlp_forward.cu volume_render.cu ngp_validate.cu

# 2. Run validation + benchmarks
build\ngp_validate.exe

# 3. Dump SASS for inspection
nvcc -arch=sm_89 -O2 -allow-unsupported-compiler -cubin -o build/hashgrid_encode.cubin hashgrid_encode.cu
cuobjdump -sass build/hashgrid_encode.cubin > sass_output/hashgrid_encode.sass
```

## Validation Results (RTX 4070 Ti Super, 262K points, -O2)

All three kernels pass bit-level or near-bit-level validation against reference CUDA:

| Kernel | Max Error | Mean Error | Speedup vs Reference |
|--------|-----------|------------|---------------------|
| Hash Grid Encoding (v3) | 0.00e+00 (exact) | 0.00e+00 | **1.11x** |
| MLP Forward | 1.19e-07 | 8.69e-09 | **3.16x** |
| Volume Rendering | 2.98e-07 | 4.26e-08 | **1.53x** |

**Analysis:**
- **MLP 3.16x** (compute-bound): 8-wide ILP FMA chains + shared memory weight tiling gives dominant speedup. Compiler can't match manual ILP management.
- **Hash Grid 1.11x** (memory-bound): float2 vectorized loads (96 LDG.E.64 vs ref's ~192 LDG.E.32) + software pipelining across level pairs. 11% on a memory-bound kernel is a legitimate win — every % requires architectural understanding.
- **Volume Rendering 1.53x** (mixed): MUFU.EX2 fast-exp + lean compositing loop + predicated early exit.

**Optimization history (hash grid):**

| Version | Change | Speedup | 
|---------|--------|---------|
| v1 | All `asm volatile` | 0.69x (SLOWER!) |
| v2 | Non-volatile asm + C trilinear + `__ldg()` | 1.03x |
| v3 | float2 loads + SW pipelining + -O2 | **1.11x** |

Root cause of v1 regression: `asm volatile` on every instruction creates ordering barriers, preventing ptxas from interleaving LDG (~200-cycle L2 latency) with ALU compute. Fixed by using non-volatile `asm` for compute and plain C for trilinear interpolation.

## SASS Instruction Counts (PTX kernels only)

Disassembled from cubins compiled with `nvcc -arch=sm_89 -O2`:

| Instruction | Hash Grid (v3) | MLP Forward | Volume Render |
|------------|----------------|-------------|--------------|
| FFMA       | 168            | 6249        | 14           |
| IMAD       | 69             | 20          | 23           |
| IADD3      | 215            | —           | —            |
| LOP3       | 192            | 38          | 0            |
| MUFU       | 0              | 14          | 4            |
| FMNMX      | 0              | 130         | 0            |
| LDG.E.64   | 96             | —           | —            |
| LDG (total)| 99*            | 386         | 7            |
| LDS        | 0              | 1553        | 0            |
| STG        | 24             | 2           | 6            |
| SHF        | 82             | —           | —            |
| F2I        | 36             | —           | —            |
| Registers  | 42             | 40          | —            |

*Hash grid v3: 96 LDG.E.64.CONSTANT (float2 vectorized) + 3 position loads.
Reference kernel uses 19 LDG.E.32 in a loop (~192 dynamic scalar loads).

## Architecture Notes

All kernels target SM 8.9 (Ada Lovelace, RTX 4070 Ti Super):
- 128 FP32 units per SM, 4 sub-partitions
- IADD3 (3-input add), LOP3 (3-input logic), IMAD (32-bit integer FMA)
- FFMA latency: ~4.5 cycles, throughput: 128 ops/clk/SM
- LDG latency: ~33 cycles (L1 hit), ~200 cycles (L2)
- Shared memory: 100 KB per SM, ~23 cycle latency
