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
    unsigned int payload0 = 0xffffffffu;
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
    optixSetPayload_0(0x100u + optixGetPrimitiveIndex());
}
