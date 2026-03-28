/*
 * Host-managed OptiX real pipeline probe.
 *
 * This probe family is executed via the custom runner:
 *   src/sass_re/runners/optix_real_pipeline_runner.cu
 *
 * The runner builds a real OptiX pipeline with:
 *   - PTX module compiled from the companion device program source
 *   - triangle GAS via optixAccelBuild()
 *   - raygen, miss, and hitgroup program groups
 *   - SBT records packed with optixSbtRecordPackHeader()
 *   - optixLaunch() writing a payload-derived result back to CUDA memory
 *
 * This file is intentionally host-managed and skipped by raw cubin sweeps.
 */
