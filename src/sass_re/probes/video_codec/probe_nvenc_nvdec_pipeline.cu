/*
 * Host-managed NVENC/NVDEC probe.
 *
 * This probe family is executed via:
 *   src/sass_re/runners/nvenc_nvdec_pipeline_runner.cu
 *
 * The runner:
 *   - creates a CUDA context
 *   - queries NVDEC decode capabilities with cuvidGetDecoderCaps()
 *   - creates and destroys a real CUVID decoder object
 *   - opens a real NVENC encode session
 *   - queries supported encode GUIDs and preset configuration
 *   - initializes a small H.264 encode session bound to the CUDA context
 *
 * This file is intentionally host-managed and skipped by raw cubin sweeps.
 */
