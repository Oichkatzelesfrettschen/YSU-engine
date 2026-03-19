# Original Author and Project History

This project was originally created by **Umut Korkmaz**.

The narrative below is preserved from the original README to provide context
on the project's origins and the author's perspective at the time of writing.

---

## Original Author Statement

> I reverse-engineered NVIDIA's Ada Lovelace GPU assembly (SASS), measured
> instruction latencies they don't publish, then used that to hand-write
> Instant-NGP's hot loops in inline PTX -- MLP inference 3.16x faster than
> what nvcc generates. The whole thing sits on top of a 35,000-line C11
> engine I built from scratch: path tracer, Vulkan GPU compute, NeRF
> inference, mesh editor, nuclear reactor sim. I'm 16.

> 35K lines of C/CUDA/GLSL, zero frameworks -- CPU path tracer with adaptive
> sampling and deterministic RNG, Vulkan compute with 28 render modes and
> hybrid mesh+NeRF, RBMK-1000 nuclear reactor thermal simulation with real
> IAEA material correlations, quantum orbital raymarcher, Blender-style mesh
> editor. All from scratch.

## Instant-NGP Optimization Journey

The hash grid kernel went through three optimization iterations:

- **v1**: Used `asm volatile` everywhere -- regressed to 0.69x (volatile
  barriers killed load/compute interleaving).
- **v2**: Switched to non-volatile asm + pure C trilinear -- reached parity
  (1.03x).
- **v3**: Added float2 vectorized loads and software pipelining -- achieved
  1.11x win.

Every dead end and fix was documented in the process.

## Hardware Request (Original)

> I'm looking for a Blackwell GPU (RTX 5080 Ti / B200) to extend the SASS
> measurements to SM 10.0. The multi-arch pipeline is already built -- I just
> need the hardware. If you have one gathering dust or can lend cloud access,
> the comparison paper writes itself.

## Contact

- **Original author**: Umut Korkmaz
- **Email**: umut7korkmaz@gmail.com
- **Original GitHub**: [github.com/ismail0098-lang/YSU-engine](https://github.com/ismail0098-lang/YSU-engine)
