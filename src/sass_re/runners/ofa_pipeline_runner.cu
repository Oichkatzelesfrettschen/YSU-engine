#include <cuda.h>

#include <nvidia/opticalflow/nvOpticalFlowCommon.h>
#include <nvidia/opticalflow/nvOpticalFlowCuda.h>

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static int check_drv(CUresult err, const char *file, int line) {
    if (err != CUDA_SUCCESS) {
        const char *name = "CUDA_ERROR_UNKNOWN";
        const char *msg = "";
        cuGetErrorName(err, &name);
        cuGetErrorString(err, &msg);
        fprintf(stderr, "CUDA driver error: %s (%d) %s at %s:%d\n",
                name, (int)err, msg ? msg : "", file, line);
        return 1;
    }
    return 0;
}

static int check_of(NV_OF_STATUS err, const char *file, int line) {
    if (err != NV_OF_SUCCESS) {
        fprintf(stderr, "OFA error: %d at %s:%d\n", (int)err, file, line);
        return 1;
    }
    return 0;
}

#define CHECK_DRV(expr) do { if (check_drv((expr), __FILE__, __LINE__)) return 1; } while (0)
#define CHECK_OF(expr) do { if (check_of((expr), __FILE__, __LINE__)) return 1; } while (0)

int main(void) {
    const uint32_t width = 64;
    const uint32_t height = 64;
    const uint32_t grid = 4;
    const uint32_t flow_w = width / grid;
    const uint32_t flow_h = height / grid;

    CHECK_DRV(cuInit(0));
    CUdevice dev = 0;
    CHECK_DRV(cuDeviceGet(&dev, 0));
    CUcontext ctx = nullptr;
    CHECK_DRV(cuCtxCreate(&ctx, nullptr, 0, dev));

    uint32_t max_api = 0;
    CHECK_OF(NvOFGetMaxSupportedApiVersion(&max_api));
    printf("ofa_max_api=0x%x\n", max_api);

    NV_OF_CUDA_API_FUNCTION_LIST api = {};
    CHECK_OF(NvOFAPICreateInstanceCuda(NV_OF_API_VERSION, &api));

    NvOFHandle of = nullptr;
    CHECK_OF(api.nvCreateOpticalFlowCuda(ctx, &of));

    uint32_t caps_vals[16] = {};
    uint32_t caps_size = 16;
    CHECK_OF(api.nvOFGetCaps(of, NV_OF_CAPS_SUPPORTED_OUTPUT_GRID_SIZES, caps_vals, &caps_size));
    printf("ofa_supported_grids=");
    for (uint32_t i = 0; i < caps_size; ++i) {
        printf("%s%u", i ? "," : "", caps_vals[i]);
    }
    printf("\n");

    NV_OF_INIT_PARAMS init = {};
    init.width = width;
    init.height = height;
    init.outGridSize = NV_OF_OUTPUT_VECTOR_GRID_SIZE_4;
    init.hintGridSize = NV_OF_HINT_VECTOR_GRID_SIZE_UNDEFINED;
    init.mode = NV_OF_MODE_OPTICALFLOW;
    init.perfLevel = NV_OF_PERF_LEVEL_FAST;
    init.enableExternalHints = NV_OF_FALSE;
    init.enableOutputCost = NV_OF_FALSE;
    init.hPrivData = nullptr;
    init.disparityRange = NV_OF_STEREO_DISPARITY_RANGE_UNDEFINED;
    init.enableRoi = NV_OF_FALSE;
    CHECK_OF(api.nvOFInit(of, &init));

    NV_OF_BUFFER_DESCRIPTOR input_desc = {};
    input_desc.width = width;
    input_desc.height = height;
    input_desc.bufferUsage = NV_OF_BUFFER_USAGE_INPUT;
    input_desc.bufferFormat = NV_OF_BUFFER_FORMAT_GRAYSCALE8;

    NV_OF_BUFFER_DESCRIPTOR output_desc = {};
    output_desc.width = flow_w;
    output_desc.height = flow_h;
    output_desc.bufferUsage = NV_OF_BUFFER_USAGE_OUTPUT;
    output_desc.bufferFormat = NV_OF_BUFFER_FORMAT_SHORT2;

    NvOFGPUBufferHandle input0 = nullptr;
    NvOFGPUBufferHandle input1 = nullptr;
    NvOFGPUBufferHandle output = nullptr;
    CHECK_OF(api.nvOFCreateGPUBufferCuda(of, &input_desc, NV_OF_CUDA_BUFFER_TYPE_CUDEVICEPTR, &input0));
    CHECK_OF(api.nvOFCreateGPUBufferCuda(of, &input_desc, NV_OF_CUDA_BUFFER_TYPE_CUDEVICEPTR, &input1));
    CHECK_OF(api.nvOFCreateGPUBufferCuda(of, &output_desc, NV_OF_CUDA_BUFFER_TYPE_CUDEVICEPTR, &output));

    CUdeviceptr d_input0 = api.nvOFGPUBufferGetCUdeviceptr(input0);
    CUdeviceptr d_input1 = api.nvOFGPUBufferGetCUdeviceptr(input1);
    CUdeviceptr d_output = api.nvOFGPUBufferGetCUdeviceptr(output);

    unsigned char host0[width * height];
    unsigned char host1[width * height];
    memset(host0, 0, sizeof(host0));
    memset(host1, 0, sizeof(host1));
    for (uint32_t y = 20; y < 36; ++y) {
        for (uint32_t x = 16; x < 32; ++x) {
            host0[y * width + x] = 255;
            host1[y * width + (x + 4)] = 255;
        }
    }

    CHECK_DRV(cuMemcpyHtoD(d_input0, host0, sizeof(host0)));
    CHECK_DRV(cuMemcpyHtoD(d_input1, host1, sizeof(host1)));

    NV_OF_EXECUTE_INPUT_PARAMS exec_in = {};
    exec_in.inputFrame = input0;
    exec_in.referenceFrame = input1;
    exec_in.externalHints = nullptr;
    exec_in.disableTemporalHints = NV_OF_TRUE;
    exec_in.hPrivData = nullptr;
    exec_in.numRois = 0;
    exec_in.roiData = nullptr;

    NV_OF_EXECUTE_OUTPUT_PARAMS exec_out = {};
    exec_out.outputBuffer = output;
    exec_out.outputCostBuffer = nullptr;
    exec_out.hPrivData = nullptr;

    CHECK_OF(api.nvOFExecute(of, &exec_in, &exec_out));
    CHECK_DRV(cuCtxSynchronize());

    NV_OF_FLOW_VECTOR flow[flow_w * flow_h];
    memset(flow, 0, sizeof(flow));
    CHECK_DRV(cuMemcpyDtoH(flow, d_output, sizeof(flow)));

    const NV_OF_FLOW_VECTOR center = flow[(flow_h / 2) * flow_w + (flow_w / 2)];
    const float flow_x = center.flowx / 32.0f;
    const float flow_y = center.flowy / 32.0f;
    printf("ofa_center_flow=(%.3f,%.3f)\n", flow_x, flow_y);

    if (fabsf(flow_x) < 1.0f) {
        fprintf(stderr, "unexpected OFA horizontal flow magnitude: %.3f\n", flow_x);
        return 2;
    }

    api.nvOFDestroyGPUBufferCuda(output);
    api.nvOFDestroyGPUBufferCuda(input1);
    api.nvOFDestroyGPUBufferCuda(input0);
    api.nvOFDestroy(of);
    cuCtxDestroy(ctx);
    return 0;
}
