# Hybrid CPU+GPU NeRF Pipeline Notes (AVX2, 4096 batch)

## Current scaffolding
- Ray batch SOA: `nerf_batch.h/.c`
- Scheduler stub: `nerf_scheduler.h/.c`

## Intended integration points
1) Build full‑frame ray list (camera + pixel mapping).
2) Call `nerf_schedule_split()` to get CPU/GPU queues.
3) GPU queue → Vulkan compute (hash grid + MLP eval).
4) CPU queue → AVX2 batch evaluator.
5) Merge results by pixel id.

## Default parameters
- AVX2 batch size: 4096
- CPU/GPU split: placeholder even/odd

## Next steps
- Add a cost model (variance + occupancy + foveation).
- Add occupancy‑guided skipping before batching.
- Implement GPU eval kernel for hash grid + MLP weights.
- Add CPU AVX2 evaluator for the same network weights.
