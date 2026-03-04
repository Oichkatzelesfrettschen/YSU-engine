# YSU Engine Checkpoints (for AI agents)

This checklist captures the actionable checkpoints described in `.github/copilot-instructions.md` and embeds them as a discoverable repo artifact.

- [ ] Read the big picture: `ysu_main.c` -> `render.c` -> primitives/BVH -> denoiser.
- [ ] Inspect renderer threading: `render.c` (`render_scene_st` and `render_scene_mt`, `WorkerLocal`, per-thread RNG).
- [ ] Verify deterministic RNG: `ysu_seed_pixel`, `ysu_hash_u32`, per-tile seeding in `render.c`.
- [ ] Review adaptive sampling config and stats: `YSU_ADAPTIVE`, `YSU_SPP_MIN`, `YSU_SPP_BATCH`, `YSU_REL_ERR`, `YSU_ABS_ERR` in `render.c`.
- [ ] Confirm BVH & primitives: `bvh.c`, `sphere.c`, `triangle.c` (look for `sphere_intersect` usage).
- [ ] Check image output & dumps: `image.c`, `ysu_main.c` (`YSU_DUMP_RGB`, `output.ppm`, `output_color.ysub`).
- [ ] Inspect neural/ONNX denoiser integration: `neural_denoise.c`, `onnx_denoise.c`, and `shaders/` for SPV assets.
- [ ] Follow naming conventions: prefer `ysu_`-prefixed helpers when adding public APIs.
- [ ] When changing concurrency/state: preserve `_Atomic` counters and `WorkerLocal` alignment (avoid false sharing).
- [ ] Editor-specific limits: `ysu_mesh_edit.c` uses `MAX_VERTS` / `MAX_TRIS` — respect these fixed caps.
- [ ] Build note: project requires C11. Example:

```
gcc -std=c11 -O2 -pthread -o ysu ysu_main.c render.c vec3.c ray.c camera.c image.c sphere.c triangle.c bvh.c material.c neural_denoise.c onnx_denoise.c
```

- [ ] Local run examples:
  - Fast debug: `YSU_W=320 YSU_H=180 YSU_SPP=4 YSU_THREADS=0 ./ysu`
  - Adaptive + denoise: `YSU_ADAPTIVE=1 YSU_NEURAL_DENOISE=1 ./ysu`

If you'd like these checkpoints inserted as inline TODO comments in additional files, tell me which files or which checkpoint items to inline and I'll add them.
