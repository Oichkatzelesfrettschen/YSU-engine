/*
 * Host-managed cuDNN convolution and library-mining probe.
 *
 * Executed via the custom runner:
 *   src/sass_re/runners/cudnn_conv_mining_runner.cu
 *
 * The runner:
 *   - builds a small cuDNN forward-convolution workload
 *   - exercises the installed cuDNN runtime on the local Ada GPU
 *   - reports the selected forward algorithm and workspace size
 *   - provides a stable process target for Nsight Compute
 *
 * Mnemonic mining for cuDNN engine libraries is handled by:
 *   src/sass_re/scripts/mine_cudnn_library_mnemonics.sh
 *
 * This file is intentionally host-managed and skipped by raw cubin sweeps.
 */
