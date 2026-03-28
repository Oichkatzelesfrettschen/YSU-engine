#include <cuda.h>
#include <cuda_runtime.h>

#include <optix/optix.h>
#include <optix/optix_function_table_definition.h>
#include <optix/optix_host.h>
#include <optix/optix_stack_size.h>
#include <optix/optix_stubs.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fstream>
#include <string>

struct Params {
    OptixTraversableHandle handle;
    unsigned int *result;
};

template <typename T>
struct __align__(OPTIX_SBT_RECORD_ALIGNMENT) SbtRecord {
    char header[OPTIX_SBT_RECORD_HEADER_SIZE];
    T data;
};

struct EmptyData {
};

static int check_cuda_rt(cudaError_t err, const char *file, int line) {
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA runtime error: %s (%d) at %s:%d\n",
                cudaGetErrorString(err), (int)err, file, line);
        return 1;
    }
    return 0;
}

static int check_cuda_drv(CUresult err, const char *file, int line) {
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

static int check_optix(OptixResult err, const char *file, int line) {
    if (err != OPTIX_SUCCESS) {
        fprintf(stderr, "OptiX error: %d at %s:%d\n", (int)err, file, line);
        return 1;
    }
    return 0;
}

#define CHECK_CUDA_RT(expr) do { if (check_cuda_rt((expr), __FILE__, __LINE__)) return 1; } while (0)
#define CHECK_CUDA_DRV(expr) do { if (check_cuda_drv((expr), __FILE__, __LINE__)) return 1; } while (0)
#define CHECK_OPTIX(expr) do { if (check_optix((expr), __FILE__, __LINE__)) return 1; } while (0)

static void optix_log_callback(unsigned int level, const char *tag, const char *msg, void *) {
    if (level <= 3) {
        fprintf(stderr, "[OptiX %u][%s] %s\n", level, tag ? tag : "log", msg ? msg : "");
    }
}

static std::string read_text_file(const char *path) {
    std::ifstream file(path, std::ios::in | std::ios::binary);
    if (!file) {
        fprintf(stderr, "failed to open PTX file: %s\n", path);
        return std::string();
    }
    return std::string((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <ptx_file>\n", argv[0]);
        return 2;
    }

    const char *ptx_path = argv[1];
    std::string ptx = read_text_file(ptx_path);
    if (ptx.empty()) {
        return 1;
    }

    CHECK_CUDA_DRV(cuInit(0));
    CHECK_CUDA_RT(cudaSetDevice(0));

    CUcontext cu_ctx = nullptr;
    CHECK_CUDA_DRV(cuCtxGetCurrent(&cu_ctx));
    if (!cu_ctx) {
        fprintf(stderr, "missing CUDA context after cudaSetDevice\n");
        return 1;
    }

    CHECK_OPTIX(optixInit());

    OptixDeviceContextOptions ctx_options = {};
    ctx_options.logCallbackFunction = optix_log_callback;
    ctx_options.logCallbackLevel = 4;

    OptixDeviceContext optix_ctx = nullptr;
    CHECK_OPTIX(optixDeviceContextCreate(cu_ctx, &ctx_options, &optix_ctx));

    OptixModuleCompileOptions module_options = {};
    module_options.maxRegisterCount = OPTIX_COMPILE_DEFAULT_MAX_REGISTER_COUNT;
    module_options.optLevel = OPTIX_COMPILE_OPTIMIZATION_DEFAULT;
    module_options.debugLevel = OPTIX_COMPILE_DEBUG_LEVEL_MINIMAL;

    OptixPipelineCompileOptions pipeline_options = {};
    pipeline_options.usesMotionBlur = 0;
    pipeline_options.traversableGraphFlags = OPTIX_TRAVERSABLE_GRAPH_FLAG_ALLOW_SINGLE_GAS;
    pipeline_options.numPayloadValues = 1;
    pipeline_options.numAttributeValues = 2;
    pipeline_options.exceptionFlags = OPTIX_EXCEPTION_FLAG_NONE;
    pipeline_options.pipelineLaunchParamsVariableName = "params";
    pipeline_options.usesPrimitiveTypeFlags = OPTIX_PRIMITIVE_TYPE_FLAGS_TRIANGLE;

    char log[4096];
    size_t log_size = sizeof(log);
    OptixModule module = nullptr;
    CHECK_OPTIX(optixModuleCreate(optix_ctx,
                                  &module_options,
                                  &pipeline_options,
                                  ptx.c_str(),
                                  ptx.size(),
                                  log,
                                  &log_size,
                                  &module));
    if (log_size > 1) {
        fprintf(stderr, "[optixModuleCreate log] %s\n", log);
    }

    OptixProgramGroupOptions pg_options = {};

    OptixProgramGroupDesc raygen_desc = {};
    raygen_desc.kind = OPTIX_PROGRAM_GROUP_KIND_RAYGEN;
    raygen_desc.raygen.module = module;
    raygen_desc.raygen.entryFunctionName = "__raygen__probe";

    OptixProgramGroupDesc miss_desc = {};
    miss_desc.kind = OPTIX_PROGRAM_GROUP_KIND_MISS;
    miss_desc.miss.module = module;
    miss_desc.miss.entryFunctionName = "__miss__probe";

    OptixProgramGroupDesc hit_desc = {};
    hit_desc.kind = OPTIX_PROGRAM_GROUP_KIND_HITGROUP;
    hit_desc.hitgroup.moduleCH = module;
    hit_desc.hitgroup.entryFunctionNameCH = "__closesthit__probe";

    OptixProgramGroupDesc direct_desc = {};
    direct_desc.kind = OPTIX_PROGRAM_GROUP_KIND_CALLABLES;
    direct_desc.callables.moduleDC = module;
    direct_desc.callables.entryFunctionNameDC = "__direct_callable__probe";

    OptixProgramGroupDesc cont_desc = {};
    cont_desc.kind = OPTIX_PROGRAM_GROUP_KIND_CALLABLES;
    cont_desc.callables.moduleCC = module;
    cont_desc.callables.entryFunctionNameCC = "__continuation_callable__probe";

    OptixProgramGroup raygen_pg = nullptr;
    OptixProgramGroup miss_pg = nullptr;
    OptixProgramGroup hit_pg = nullptr;
    OptixProgramGroup direct_pg = nullptr;
    OptixProgramGroup cont_pg = nullptr;

    log_size = sizeof(log);
    CHECK_OPTIX(optixProgramGroupCreate(optix_ctx, &raygen_desc, 1, &pg_options, log, &log_size, &raygen_pg));
    log_size = sizeof(log);
    CHECK_OPTIX(optixProgramGroupCreate(optix_ctx, &miss_desc, 1, &pg_options, log, &log_size, &miss_pg));
    log_size = sizeof(log);
    CHECK_OPTIX(optixProgramGroupCreate(optix_ctx, &hit_desc, 1, &pg_options, log, &log_size, &hit_pg));
    log_size = sizeof(log);
    CHECK_OPTIX(optixProgramGroupCreate(optix_ctx, &direct_desc, 1, &pg_options, log, &log_size, &direct_pg));
    log_size = sizeof(log);
    CHECK_OPTIX(optixProgramGroupCreate(optix_ctx, &cont_desc, 1, &pg_options, log, &log_size, &cont_pg));

    OptixProgramGroup groups[] = { raygen_pg, miss_pg, hit_pg, direct_pg, cont_pg };
    OptixPipelineLinkOptions link_options = {};
    link_options.maxTraceDepth = 1;

    OptixPipeline pipeline = nullptr;
    log_size = sizeof(log);
    CHECK_OPTIX(optixPipelineCreate(optix_ctx,
                                    &pipeline_options,
                                    &link_options,
                                    groups,
                                    5,
                                    log,
                                    &log_size,
                                    &pipeline));
    if (log_size > 1) {
        fprintf(stderr, "[optixPipelineCreate log] %s\n", log);
    }

    OptixStackSizes stack_sizes = {};
    CHECK_OPTIX(optixUtilAccumulateStackSizes(raygen_pg, &stack_sizes, pipeline));
    CHECK_OPTIX(optixUtilAccumulateStackSizes(miss_pg, &stack_sizes, pipeline));
    CHECK_OPTIX(optixUtilAccumulateStackSizes(hit_pg, &stack_sizes, pipeline));
    CHECK_OPTIX(optixUtilAccumulateStackSizes(direct_pg, &stack_sizes, pipeline));
    CHECK_OPTIX(optixUtilAccumulateStackSizes(cont_pg, &stack_sizes, pipeline));

    uint32_t dss_trav = 0;
    uint32_t dss_state = 0;
    uint32_t css = 0;
    CHECK_OPTIX(optixUtilComputeStackSizes(&stack_sizes, 1, 1, 1, &dss_trav, &dss_state, &css));
    CHECK_OPTIX(optixPipelineSetStackSize(pipeline, dss_trav, dss_state, css, 1));

    float vertices[9] = {
        0.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
    };
    CUdeviceptr d_vertices = 0;
    CHECK_CUDA_DRV(cuMemAlloc(&d_vertices, sizeof(vertices)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_vertices, vertices, sizeof(vertices)));

    uint32_t triangle_input_flags[1] = { OPTIX_GEOMETRY_FLAG_NONE };
    OptixBuildInput build_input = {};
    build_input.type = OPTIX_BUILD_INPUT_TYPE_TRIANGLES;
    build_input.triangleArray.vertexFormat = OPTIX_VERTEX_FORMAT_FLOAT3;
    build_input.triangleArray.vertexStrideInBytes = sizeof(float) * 3;
    build_input.triangleArray.numVertices = 3;
    build_input.triangleArray.vertexBuffers = &d_vertices;
    build_input.triangleArray.flags = triangle_input_flags;
    build_input.triangleArray.numSbtRecords = 1;

    OptixAccelBuildOptions accel_options = {};
    accel_options.buildFlags = OPTIX_BUILD_FLAG_NONE;
    accel_options.operation = OPTIX_BUILD_OPERATION_BUILD;

    OptixAccelBufferSizes buffer_sizes = {};
    CHECK_OPTIX(optixAccelComputeMemoryUsage(optix_ctx, &accel_options, &build_input, 1, &buffer_sizes));

    CUdeviceptr d_temp = 0;
    CUdeviceptr d_gas = 0;
    CHECK_CUDA_DRV(cuMemAlloc(&d_temp, buffer_sizes.tempSizeInBytes));
    CHECK_CUDA_DRV(cuMemAlloc(&d_gas, buffer_sizes.outputSizeInBytes));

    OptixTraversableHandle gas_handle = {};
    CHECK_OPTIX(optixAccelBuild(optix_ctx,
                                0,
                                &accel_options,
                                &build_input,
                                1,
                                d_temp,
                                buffer_sizes.tempSizeInBytes,
                                d_gas,
                                buffer_sizes.outputSizeInBytes,
                                &gas_handle,
                                nullptr,
                                0));
    CHECK_CUDA_RT(cudaDeviceSynchronize());

    SbtRecord<EmptyData> rg_record = {};
    SbtRecord<EmptyData> ms_record = {};
    SbtRecord<EmptyData> hg_record = {};
    SbtRecord<EmptyData> direct_record = {};
    SbtRecord<EmptyData> cont_record = {};
    CHECK_OPTIX(optixSbtRecordPackHeader(raygen_pg, &rg_record));
    CHECK_OPTIX(optixSbtRecordPackHeader(miss_pg, &ms_record));
    CHECK_OPTIX(optixSbtRecordPackHeader(hit_pg, &hg_record));
    CHECK_OPTIX(optixSbtRecordPackHeader(direct_pg, &direct_record));
    CHECK_OPTIX(optixSbtRecordPackHeader(cont_pg, &cont_record));

    CUdeviceptr d_rg = 0;
    CUdeviceptr d_ms = 0;
    CUdeviceptr d_hg = 0;
    CUdeviceptr d_callables = 0;
    SbtRecord<EmptyData> callables_records[2] = { direct_record, cont_record };
    CHECK_CUDA_DRV(cuMemAlloc(&d_rg, sizeof(rg_record)));
    CHECK_CUDA_DRV(cuMemAlloc(&d_ms, sizeof(ms_record)));
    CHECK_CUDA_DRV(cuMemAlloc(&d_hg, sizeof(hg_record)));
    CHECK_CUDA_DRV(cuMemAlloc(&d_callables, sizeof(callables_records)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_rg, &rg_record, sizeof(rg_record)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_ms, &ms_record, sizeof(ms_record)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_hg, &hg_record, sizeof(hg_record)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_callables, callables_records, sizeof(callables_records)));

    OptixShaderBindingTable sbt = {};
    sbt.raygenRecord = d_rg;
    sbt.missRecordBase = d_ms;
    sbt.missRecordStrideInBytes = sizeof(ms_record);
    sbt.missRecordCount = 1;
    sbt.hitgroupRecordBase = d_hg;
    sbt.hitgroupRecordStrideInBytes = sizeof(hg_record);
    sbt.hitgroupRecordCount = 1;
    sbt.callablesRecordBase = d_callables;
    sbt.callablesRecordStrideInBytes = sizeof(SbtRecord<EmptyData>);
    sbt.callablesRecordCount = 2;

    unsigned int *d_result = nullptr;
    CHECK_CUDA_RT(cudaMalloc(reinterpret_cast<void **>(&d_result), sizeof(unsigned int)));
    CHECK_CUDA_RT(cudaMemset(d_result, 0xff, sizeof(unsigned int)));

    Params params = {};
    params.handle = gas_handle;
    params.result = d_result;

    CUdeviceptr d_params = 0;
    CHECK_CUDA_DRV(cuMemAlloc(&d_params, sizeof(Params)));
    CHECK_CUDA_DRV(cuMemcpyHtoD(d_params, &params, sizeof(params)));

    CHECK_OPTIX(optixLaunch(pipeline, 0, d_params, sizeof(Params), &sbt, 1, 1, 1));
    CHECK_CUDA_RT(cudaDeviceSynchronize());

    unsigned int result = 0;
    CHECK_CUDA_RT(cudaMemcpy(&result, d_result, sizeof(result), cudaMemcpyDeviceToHost));
    printf("optix_callable_pipeline_result=0x%08x\n", result);
    if (result != 0x117u) {
        fprintf(stderr, "unexpected OptiX callable payload result: 0x%08x\n", result);
        return 2;
    }

    cudaFree(d_result);
    cuMemFree(d_params);
    cuMemFree(d_callables);
    cuMemFree(d_hg);
    cuMemFree(d_ms);
    cuMemFree(d_rg);
    cuMemFree(d_temp);
    cuMemFree(d_gas);
    cuMemFree(d_vertices);
    optixPipelineDestroy(pipeline);
    optixProgramGroupDestroy(cont_pg);
    optixProgramGroupDestroy(direct_pg);
    optixProgramGroupDestroy(hit_pg);
    optixProgramGroupDestroy(miss_pg);
    optixProgramGroupDestroy(raygen_pg);
    optixModuleDestroy(module);
    optixDeviceContextDestroy(optix_ctx);
    return 0;
}
