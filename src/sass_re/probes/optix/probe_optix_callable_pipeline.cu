/*
 * Host-managed OptiX callable-pipeline probe.
 *
 * Executed via the custom runner:
 *   src/sass_re/runners/optix_callable_pipeline_runner.cu
 *
 * The runner builds an OptiX pipeline with:
 *   - a raygen/miss/hitgroup set
 *   - one direct callable program
 *   - one continuation callable program
 *   - a callables SBT section
 *   - explicit stack sizing for direct and continuation call depth
 *
 * This file is intentionally host-managed and skipped by raw cubin sweeps.
 */
