#include <cuda_runtime.h>

#include <cudnn.h>
#include <cudnn_cnn.h>
#include <cudnn_ops.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int check_cuda(cudaError_t err, const char *file, int line) {
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA runtime error: %s (%d) at %s:%d\n",
                cudaGetErrorString(err), (int)err, file, line);
        return 1;
    }
    return 0;
}

static int check_cudnn(cudnnStatus_t err, const char *file, int line) {
    if (err != CUDNN_STATUS_SUCCESS) {
        fprintf(stderr, "cuDNN error: %s (%d) at %s:%d\n",
                cudnnGetErrorString(err), (int)err, file, line);
        return 1;
    }
    return 0;
}

#define CHECK_CUDA(expr) do { if (check_cuda((expr), __FILE__, __LINE__)) return 1; } while (0)
#define CHECK_CUDNN(expr) do { if (check_cudnn((expr), __FILE__, __LINE__)) return 1; } while (0)

int main(void) {
    const int n = 1;
    const int c = 16;
    const int h = 16;
    const int w = 16;
    const int k = 32;
    const int r = 3;
    const int s = 3;
    const int pad_h = 1;
    const int pad_w = 1;
    const int stride_h = 1;
    const int stride_w = 1;
    const int dil_h = 1;
    const int dil_w = 1;

    printf("cudnn_version=%zu\n", cudnnGetVersion());
    CHECK_CUDA(cudaSetDevice(0));

    cudnnHandle_t handle = nullptr;
    cudnnTensorDescriptor_t x_desc = nullptr;
    cudnnTensorDescriptor_t y_desc = nullptr;
    cudnnFilterDescriptor_t w_desc = nullptr;
    cudnnConvolutionDescriptor_t conv_desc = nullptr;

    CHECK_CUDNN(cudnnCreate(&handle));
    CHECK_CUDNN(cudnnCreateTensorDescriptor(&x_desc));
    CHECK_CUDNN(cudnnCreateTensorDescriptor(&y_desc));
    CHECK_CUDNN(cudnnCreateFilterDescriptor(&w_desc));
    CHECK_CUDNN(cudnnCreateConvolutionDescriptor(&conv_desc));

    CHECK_CUDNN(cudnnSetTensor4dDescriptor(
        x_desc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, n, c, h, w));
    CHECK_CUDNN(cudnnSetFilter4dDescriptor(
        w_desc, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW, k, c, r, s));
    CHECK_CUDNN(cudnnSetConvolution2dDescriptor(
        conv_desc,
        pad_h,
        pad_w,
        stride_h,
        stride_w,
        dil_h,
        dil_w,
        CUDNN_CROSS_CORRELATION,
        CUDNN_DATA_FLOAT));
    CHECK_CUDNN(cudnnSetConvolutionMathType(conv_desc, CUDNN_DEFAULT_MATH));

    int out_n = 0;
    int out_c = 0;
    int out_h = 0;
    int out_w = 0;
    CHECK_CUDNN(cudnnGetConvolution2dForwardOutputDim(
        conv_desc, x_desc, w_desc, &out_n, &out_c, &out_h, &out_w));
    CHECK_CUDNN(cudnnSetTensor4dDescriptor(
        y_desc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, out_n, out_c, out_h, out_w));

    cudnnConvolutionFwdAlgoPerf_t perf[8];
    int perf_count = 0;
    cudnnConvolutionFwdAlgo_t algo = CUDNN_CONVOLUTION_FWD_ALGO_IMPLICIT_PRECOMP_GEMM;
    cudnnMathType_t selected_math_type = CUDNN_DEFAULT_MATH;
    float selected_time = -1.0f;
    CHECK_CUDNN(cudnnGetConvolutionForwardAlgorithm_v7(
        handle, x_desc, w_desc, conv_desc, y_desc, 8, &perf_count, perf));

    int best_index = -1;
    for (int i = 0; i < perf_count; ++i) {
        if (perf[i].status == CUDNN_STATUS_SUCCESS) {
            best_index = i;
            break;
        }
    }
    if (best_index >= 0) {
        algo = perf[best_index].algo;
        selected_math_type = perf[best_index].mathType;
        selected_time = perf[best_index].time;
    } else {
        printf("cudnn_algo_query_fallback=IMPLICIT_PRECOMP_GEMM\n");
    }

    printf("cudnn_fwd_algo=%d\n", (int)algo);
    printf("cudnn_fwd_algo_math_type=%d\n", (int)selected_math_type);
    printf("cudnn_fwd_algo_time=%.6f\n", selected_time);

    size_t workspace_bytes = 0;
    CHECK_CUDNN(cudnnGetConvolutionForwardWorkspaceSize(
        handle, x_desc, w_desc, conv_desc, y_desc, algo, &workspace_bytes));
    printf("cudnn_workspace_bytes=%zu\n", workspace_bytes);

    const size_t x_elems = (size_t)n * (size_t)c * (size_t)h * (size_t)w;
    const size_t w_elems = (size_t)k * (size_t)c * (size_t)r * (size_t)s;
    const size_t y_elems = (size_t)out_n * (size_t)out_c * (size_t)out_h * (size_t)out_w;

    float *host_x = static_cast<float *>(malloc(x_elems * sizeof(float)));
    float *host_w = static_cast<float *>(malloc(w_elems * sizeof(float)));
    float *host_y = static_cast<float *>(malloc(y_elems * sizeof(float)));
    if (!host_x || !host_w || !host_y) {
        fprintf(stderr, "host allocation failed\n");
        return 3;
    }

    for (size_t i = 0; i < x_elems; ++i) {
        host_x[i] = (i % 7u == 0u) ? 1.0f : 0.5f;
    }
    for (size_t i = 0; i < w_elems; ++i) {
        host_w[i] = (i % 5u == 0u) ? 1.0f : 0.25f;
    }
    memset(host_y, 0, y_elems * sizeof(float));

    void *d_x = nullptr;
    void *d_w = nullptr;
    void *d_y = nullptr;
    void *d_workspace = nullptr;
    CHECK_CUDA(cudaMalloc(&d_x, x_elems * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_w, w_elems * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_y, y_elems * sizeof(float)));
    if (workspace_bytes != 0) {
        CHECK_CUDA(cudaMalloc(&d_workspace, workspace_bytes));
    }

    CHECK_CUDA(cudaMemcpy(d_x, host_x, x_elems * sizeof(float), cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_w, host_w, w_elems * sizeof(float), cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemset(d_y, 0, y_elems * sizeof(float)));

    const float alpha = 1.0f;
    const float beta = 0.0f;
    CHECK_CUDNN(cudnnConvolutionForward(
        handle,
        &alpha,
        x_desc,
        d_x,
        w_desc,
        d_w,
        conv_desc,
        algo,
        d_workspace,
        workspace_bytes,
        &beta,
        y_desc,
        d_y));
    CHECK_CUDA(cudaDeviceSynchronize());

    CHECK_CUDA(cudaMemcpy(host_y, d_y, y_elems * sizeof(float), cudaMemcpyDeviceToHost));

    double checksum = 0.0;
    for (size_t i = 0; i < y_elems; ++i) {
        checksum += (double)host_y[i];
    }
    printf("cudnn_output_shape=%dx%dx%dx%d\n", out_n, out_c, out_h, out_w);
    printf("cudnn_output_sample=%0.6f,%0.6f,%0.6f,%0.6f\n",
           host_y[0], host_y[1], host_y[2], host_y[3]);
    printf("cudnn_output_checksum=%0.6f\n", checksum);

    cudaFree(d_workspace);
    cudaFree(d_y);
    cudaFree(d_w);
    cudaFree(d_x);
    free(host_y);
    free(host_w);
    free(host_x);

    cudnnDestroyConvolutionDescriptor(conv_desc);
    cudnnDestroyFilterDescriptor(w_desc);
    cudnnDestroyTensorDescriptor(y_desc);
    cudnnDestroyTensorDescriptor(x_desc);
    cudnnDestroy(handle);
    return 0;
}
