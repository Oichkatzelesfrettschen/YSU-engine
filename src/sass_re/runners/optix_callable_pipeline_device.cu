#include <optix/optix.h>
#include <optix/optix_device.h>

struct Params {
    OptixTraversableHandle handle;
    unsigned int *result;
};

extern "C" {
__constant__ Params params;
}

extern "C" __global__ void __raygen__probe() {
    unsigned int payload0 = optixDirectCall<unsigned int, unsigned int>(0, 7u);
    float3 origin = make_float3(0.1f, 0.1f, -1.0f);
    float3 direction = make_float3(0.0f, 0.0f, 1.0f);
    optixTrace(
        params.handle,
        origin,
        direction,
        0.0f,
        1.0e16f,
        0.0f,
        0xff,
        OPTIX_RAY_FLAG_NONE,
        0,
        1,
        0,
        payload0);
    params.result[0] = payload0;
}

extern "C" __global__ void __miss__probe() {
    optixSetPayload_0(0xdeadbeefu);
}

extern "C" __global__ void __closesthit__probe() {
    unsigned int base = optixGetPayload_0();
    unsigned int extra = optixContinuationCall<unsigned int, unsigned int>(1, optixGetPrimitiveIndex());
    optixSetPayload_0(base + extra);
}

extern "C" __device__ unsigned int __direct_callable__probe(unsigned int x) {
    return 0x10u + x;
}

extern "C" __device__ unsigned int __continuation_callable__probe(unsigned int x) {
    return 0x100u + x;
}
