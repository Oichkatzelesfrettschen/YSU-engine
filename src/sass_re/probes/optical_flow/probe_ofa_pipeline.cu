/*
 * Host-managed Optical Flow Accelerator probe.
 *
 * This probe family is executed via:
 *   src/sass_re/runners/ofa_pipeline_runner.cu
 *
 * The runner:
 *   - creates a CUDA context
 *   - creates an NVOF CUDA handle
 *   - queries supported grid sizes and dimensions
 *   - initializes a real OFA session
 *   - allocates GPU buffers for two grayscale frames and flow vectors
 *   - executes optical flow on a synthetic shifted block pattern
 *   - copies the output vectors back for basic plausibility checks
 *
 * This file is intentionally host-managed and skipped by raw cubin sweeps.
 */
