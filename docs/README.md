# YSU Engine — Documentation Index

Organized into four categories: **SASS**, **NeRF**, **Engine**, and **Results**.

---

## [`sass/`](sass/) — SASS Reverse Engineering & GPU ISA

GPU shader assembly analysis, encoding research, and instant-NGP kernel optimization.

| Document | Description |
|----------|-------------|
| [NVIDIA_SASS_ADA_LOVELACE_REFERENCE](sass/NVIDIA_SASS_ADA_LOVELACE_REFERENCE.md) | Ada Lovelace (SM 8.9) SASS instruction reference |

**See also:** [`src/sass_re/`](../src/sass_re/) for the full SASS RE toolkit, probe kernels, and:
- [`src/sass_re/README.md`](../src/sass_re/README.md) — Toolkit overview & multi-arch pipeline
- [`src/sass_re/PAPER_OUTLINE.md`](../src/sass_re/PAPER_OUTLINE.md) — Multi-architecture comparison paper
- [`src/sass_re/RESULTS.md`](../src/sass_re/RESULTS.md) — Encoding analysis results
- [`src/sass_re/instant_ngp/README.md`](../src/sass_re/instant_ngp/README.md) — Instant-NGP SASS kernel benchmarks
- [`src/sass_re/instant_ngp/docs/`](../src/sass_re/instant_ngp/docs/) — Three-tier documentation (everyone / learners / technical)

---

## [`nerf/`](nerf/) — Neural Radiance Fields

NeRF inference, SIMD implementation, depth conditioning, and neural upscaling.

### Architecture & Design
| Document | Description |
|----------|-------------|
| [HYBRID_CPU_GPU_NERF_ARCHITECTURE](nerf/HYBRID_CPU_GPU_NERF_ARCHITECTURE.md) | CPU NeRF + GPU mesh parallel execution design |
| [HYBRID_PIPELINE_NOTES](nerf/HYBRID_PIPELINE_NOTES.md) | Pipeline integration notes |
| [YSU_NEURAL_UPSCALE_ARCHITECTURE](nerf/YSU_NEURAL_UPSCALE_ARCHITECTURE.md) | DLSS-class temporal super-resolution architecture |

### SIMD Implementation
| Document | Description |
|----------|-------------|
| [NERF_CPU_SIMD_REALTIME](nerf/NERF_CPU_SIMD_REALTIME.md) | AVX2 SIMD real-time NeRF approach |
| [NERF_SIMD_COMPLETE](nerf/NERF_SIMD_COMPLETE.md) | Full SIMD implementation documentation |
| [NERF_SIMD_QUICKREF](nerf/NERF_SIMD_QUICKREF.md) | One-page SIMD cheat sheet |
| [BUILD_NERF_SIMD](nerf/BUILD_NERF_SIMD.md) | Build & integration steps |
| [NERF_INTEGRATION_GUIDE](nerf/NERF_INTEGRATION_GUIDE.md) | How to integrate NeRF into the renderer |

### Depth-Conditioned NeRF
| Document | Description |
|----------|-------------|
| [DEPTH_CONDITIONED_NERF](nerf/DEPTH_CONDITIONED_NERF.md) | Depth conditioning overview |
| [DEPTH_CONDITIONED_NERF_QA](nerf/DEPTH_CONDITIONED_NERF_QA.md) | Q&A on depth-conditioned approach |
| [DEPTH_CONDITIONED_NERF_README](nerf/DEPTH_CONDITIONED_NERF_README.md) | Depth-conditioned NeRF readme |
| [README_DEPTH_CONDITIONED_NERF](nerf/README_DEPTH_CONDITIONED_NERF.md) | Additional depth NeRF notes |

### GPU & Optimization
| Document | Description |
|----------|-------------|
| [NERF_GPU_OPTIMIZATIONS](nerf/NERF_GPU_OPTIMIZATIONS.md) | GPU-side NeRF optimizations |
| [NERF_GPU_SHADER_DEBUG_REPORT](nerf/NERF_GPU_SHADER_DEBUG_REPORT.md) | Shader debug findings |
| [NERF_CPU_GPU_RESEARCH](nerf/NERF_CPU_GPU_RESEARCH.md) | CPU vs GPU NeRF research |

### Data & Formats
| Document | Description |
|----------|-------------|
| [NERF_CUSTOM_FORMAT](nerf/NERF_CUSTOM_FORMAT.md) | `.ysub` binary format specification |
| [README_NERF_TRAIN_EXPORT](nerf/README_NERF_TRAIN_EXPORT.md) | Training & export pipeline |
| [NERF_FIX_FLOAT16](nerf/NERF_FIX_FLOAT16.md) | Float16 precision fix |

### Troubleshooting
| Document | Description |
|----------|-------------|
| [NERF_TROUBLESHOOTING](nerf/NERF_TROUBLESHOOTING.md) | Common NeRF issues & fixes |
| [NERF_CPU_FIX_SUMMARY](nerf/NERF_CPU_FIX_SUMMARY.md) | CPU inference fix summary |
| [NERF_WALKABLE_COMPLETE](nerf/NERF_WALKABLE_COMPLETE.md) | Walkable NeRF scene completion |
| [NERF_QUICK_REF](nerf/NERF_QUICK_REF.md) | Quick reference |

---

## [`engine/`](engine/) — Renderer, Denoiser & Pipeline

Core raytracer, denoising, BVH/LBVH, GPU pipeline, and optimization.

### Denoiser
| Document | Description |
|----------|-------------|
| [README_DENOISER](engine/README_DENOISER.md) | Denoiser overview |
| [BILATERAL_DENOISE](engine/BILATERAL_DENOISE.md) | Bilateral denoiser implementation |
| [ADVANCED_DENOISE_IMPLEMENTATION](engine/ADVANCED_DENOISE_IMPLEMENTATION.md) | Advanced denoiser architecture |
| [ADVANCED_DENOISE_FEATURES](engine/ADVANCED_DENOISE_FEATURES.md) | Feature list |
| [ADVANCED_DENOISE_COMPLETE](engine/ADVANCED_DENOISE_COMPLETE.md) | Completion status |
| [ADVANCED_DENOISE_QUICK_REF](engine/ADVANCED_DENOISE_QUICK_REF.md) | Quick reference |
| [FINAL_DENOISER_REPORT](engine/FINAL_DENOISER_REPORT.md) | Final denoiser report |
| [DENOISER_STATUS](engine/DENOISER_STATUS.md) | Status tracker |
| [DENOISER_TESTING](engine/DENOISER_TESTING.md) | Test results |
| [OPTION1_DENOISE_SKIP](engine/OPTION1_DENOISE_SKIP.md) | Denoise skip optimization |
| [OPTION2_TEMPORAL_DENOISE_PLAN](engine/OPTION2_TEMPORAL_DENOISE_PLAN.md) | Temporal denoising plan |
| [OPTION2_PROGRESS](engine/OPTION2_PROGRESS.md) | Temporal denoising progress |

### GPU Pipeline & Optimization
| Document | Description |
|----------|-------------|
| [GPU_OPTIMIZATION_FINAL_REPORT](engine/GPU_OPTIMIZATION_FINAL_REPORT.md) | GPU optimization final report |
| [GPU_OPTIMIZATION_RESULTS](engine/GPU_OPTIMIZATION_RESULTS.md) | GPU optimization results |
| [GPU_OPTIMIZATION_QUICK_REF](engine/GPU_OPTIMIZATION_QUICK_REF.md) | Quick reference |
| [GPU_BUG_FIX_REPORT](engine/GPU_BUG_FIX_REPORT.md) | GPU triangle winding bug fix |
| [GPU_RENDER_SCALE_2X_BOOST](engine/GPU_RENDER_SCALE_2X_BOOST.md) | 2x render-scale FPS boost |
| [GPU_TEMPORAL_FPS_BOOST](engine/GPU_TEMPORAL_FPS_BOOST.md) | Temporal accumulation FPS boost |
| [FULL_OPTIMIZATION_GUIDE](engine/FULL_OPTIMIZATION_GUIDE.md) | Complete optimization guide |
| [README_OPTIMIZATION](engine/README_OPTIMIZATION.md) | Optimization overview |
| [README_OPTIMIZATION_INDEX](engine/README_OPTIMIZATION_INDEX.md) | Optimization index |
| [OPTIMIZATION_CODE_CHANGES](engine/OPTIMIZATION_CODE_CHANGES.md) | Code change details |
| [REALTIME_ANALYSIS](engine/REALTIME_ANALYSIS.md) | Real-time performance analysis |
| [RENDER_SCALE_CHANGES](engine/RENDER_SCALE_CHANGES.md) | Render scale implementation |

### BVH / LBVH
| Document | Description |
|----------|-------------|
| [LBVH_DISCOVERY_REPORT](engine/LBVH_DISCOVERY_REPORT.md) | LBVH discovery & analysis |
| [LBVH_INTEGRATION_COMPLETE](engine/LBVH_INTEGRATION_COMPLETE.md) | Integration completion |
| [LBVH_INTEGRATION_SUMMARY](engine/LBVH_INTEGRATION_SUMMARY.md) | Integration summary |
| [LBVH_QUICK_REFERENCE](engine/LBVH_QUICK_REFERENCE.md) | Quick reference |

### Scene & Animation
| Document | Description |
|----------|-------------|
| [ANIMATED_SCENE_SUMMARY](engine/ANIMATED_SCENE_SUMMARY.md) | Animated scene validation |
| [ANIMATED_SCENE_VALIDATION](engine/ANIMATED_SCENE_VALIDATION.md) | Animation temporal coherence |
| [QUAD_LOADER_IMPLEMENTATION](engine/QUAD_LOADER_IMPLEMENTATION.md) | Quad-aware OBJ loader |
| [COMPARE_MODES](engine/COMPARE_MODES.md) | Render mode comparison |
| [RUN_INTERACTIVE_DEMO](engine/RUN_INTERACTIVE_DEMO.md) | Interactive demo instructions |

### Platform & Build
| Document | Description |
|----------|-------------|
| [AVX_PORTABILITY](engine/AVX_PORTABILITY.md) | AVX2 portability notes |
| [STABLE_PERSISTENT_WINDOW](engine/STABLE_PERSISTENT_WINDOW.md) | Persistent window implementation |
| [WINDOW_INTERACTIVE_FIXED](engine/WINDOW_INTERACTIVE_FIXED.md) | Window interaction fixes |
| [DEBUGGING_NIGHTMARE](engine/DEBUGGING_NIGHTMARE.md) | Debug war stories |

### Feature Tracking
| Document | Description |
|----------|-------------|
| [FEATURE_IMPLEMENTATION_STATUS](engine/FEATURE_IMPLEMENTATION_STATUS.md) | Feature status tracker |
| [FEATURES_5_10_COMPLETE](engine/FEATURES_5_10_COMPLETE.md) | Features 5-10 completion |
| [FEATURES_6_10_COMPLETE](engine/FEATURES_6_10_COMPLETE.md) | Features 6-10 completion |
| [FIX_SUMMARY](engine/FIX_SUMMARY.md) | Fix summary |
| [IMPLEMENTATION_COMPLETE](engine/IMPLEMENTATION_COMPLETE.md) | Implementation completion |
| [IMPLEMENTATION_SUMMARY](engine/IMPLEMENTATION_SUMMARY.md) | Implementation summary |

---

## [`results/`](results/) — Benchmarks, Tests & Deployment

Performance results, FPS benchmarks, session logs, and deployment readiness.

### Benchmarks & FPS
| Document | Description |
|----------|-------------|
| [FINAL_FPS_RESULTS](results/FINAL_FPS_RESULTS.md) | Final FPS numbers |
| [FPS_TEST_RESULTS](results/FPS_TEST_RESULTS.md) | FPS test results |
| [FPS_TEST_RESULTS_ADVANCED](results/FPS_TEST_RESULTS_ADVANCED.md) | Advanced FPS testing |
| [FPS_TEST_COMMANDS](results/FPS_TEST_COMMANDS.md) | Test commands reference |
| [FPS_TEST_QUICK_SUMMARY](results/FPS_TEST_QUICK_SUMMARY.md) | Quick FPS summary |
| [TEST_RESULTS_1080P_60FPS](results/TEST_RESULTS_1080P_60FPS.md) | 1080p 60 FPS test results |
| [OPTIMIZATION_RESULTS_1080P_60FPS](results/OPTIMIZATION_RESULTS_1080P_60FPS.md) | 1080p optimization results |

### Project Summaries
| Document | Description |
|----------|-------------|
| [EXECUTIVE_SUMMARY](results/EXECUTIVE_SUMMARY.md) | Executive overview |
| [FINAL_PROJECT_SUMMARY](results/FINAL_PROJECT_SUMMARY.md) | Final project summary |
| [DELIVERABLES](results/DELIVERABLES.md) | Deliverables list |
| [DELIVERY_SUMMARY](results/DELIVERY_SUMMARY.md) | Delivery summary |
| [PROJECT_COMPLETION](results/PROJECT_COMPLETION.md) | Completion status |
| [STATUS_AND_ROADMAP](results/STATUS_AND_ROADMAP.md) | Status & roadmap |
| [CHANGELOG_ALL_FEATURES](results/CHANGELOG_ALL_FEATURES.md) | Full changelog |

### Deployment
| Document | Description |
|----------|-------------|
| [DEPLOY_60FPS](results/DEPLOY_60FPS.md) | 60 FPS deployment guide |
| [DEPLOYMENT_READY_1080P_60FPS](results/DEPLOYMENT_READY_1080P_60FPS.md) | 1080p deployment readiness |
| [QUICKSTART_1080P_60FPS](results/QUICKSTART_1080P_60FPS.md) | 1080p quickstart |
| [QUICK_REF_2X_BOOST](results/QUICK_REF_2X_BOOST.md) | 2x boost quick reference |
| [QUICK_REF_ANIMATED_SCENE](results/QUICK_REF_ANIMATED_SCENE.md) | Animated scene quick ref |

### Test & Verification
| Document | Description |
|----------|-------------|
| [BUILD_TEST_SUMMARY](results/BUILD_TEST_SUMMARY.md) | Build test summary |
| [COMPLETE_TEST_SUMMARY](results/COMPLETE_TEST_SUMMARY.md) | Complete test summary |
| [VERIFICATION_CHECKLIST](results/VERIFICATION_CHECKLIST.md) | Verification checklist |
| [COMPLETED_CHANGES](results/COMPLETED_CHANGES.md) | Completed changes log |

### Session Logs
| Document | Description |
|----------|-------------|
| [SESSION_13_SUMMARY](results/SESSION_13_SUMMARY.md) | Session 13 — 2x FPS boost |
| [SESSION15_COMPREHENSIVE_SUMMARY](results/SESSION15_COMPREHENSIVE_SUMMARY.md) | Session 15 — full summary |
| [SESSION15_COMPLETE_CHANGELIST](results/SESSION15_COMPLETE_CHANGELIST.md) | Session 15 — changelist |
| [SESSION15_FINAL_VERIFICATION](results/SESSION15_FINAL_VERIFICATION.md) | Session 15 — verification |
| [SESSION15_OPTION1_SUMMARY](results/SESSION15_OPTION1_SUMMARY.md) | Session 15 — option 1 |
| [SESSION15_QUICK_REFERENCE](results/SESSION15_QUICK_REFERENCE.md) | Session 15 — quick ref |
