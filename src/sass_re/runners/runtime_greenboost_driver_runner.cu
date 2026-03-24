#include <cuda.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CHECK_CU(expr) do { \
    CUresult err__ = (expr); \
    if (err__ != CUDA_SUCCESS) { \
        const char *name__ = NULL; \
        const char *str__ = NULL; \
        cuGetErrorName(err__, &name__); \
        cuGetErrorString(err__, &str__); \
        fprintf(stderr, "CUDA driver error: %s (%d) %s at %s:%d\n", \
                name__ ? name__ : "?", (int)err__, str__ ? str__ : "", __FILE__, __LINE__); \
        return 1; \
    } \
} while (0)

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

int main(int argc, char **argv) {
    const size_t bytes = (argc > 1) ? strtoull(argv[1], NULL, 10) : (size_t)(512ull * 1024ull * 1024ull);
    const int use_user_ctx = (getenv("GREENBOOST_USE_USER_CTX") && getenv("GREENBOOST_USE_USER_CTX")[0] == '1');

    CHECK_CU(cuInit(0));

    CUdevice dev;
    CHECK_CU(cuDeviceGet(&dev, 0));

    char name[256];
    memset(name, 0, sizeof(name));
    CHECK_CU(cuDeviceGetName(name, (int)sizeof(name), dev));

    unsigned int primary_flags = 0;
    int primary_active = 0;
    CHECK_CU(cuDevicePrimaryCtxGetState(dev, &primary_flags, &primary_active));

    CUcontext ctx;
    int using_primary_ctx = use_user_ctx ? 0 : 1;
    if (using_primary_ctx) {
        CHECK_CU(cuDevicePrimaryCtxRetain(&ctx, dev));
        CHECK_CU(cuCtxSetCurrent(ctx));
    } else {
        CHECK_CU(cuCtxCreate(&ctx, NULL, CU_CTX_SCHED_AUTO | CU_CTX_MAP_HOST, dev));
    }

    unsigned int ctx_flags = 0;
    CHECK_CU(cuCtxGetFlags(&ctx_flags));

    int can_map_host_memory = 0;
    int unified_addressing = 0;
    CHECK_CU(cuDeviceGetAttribute(&can_map_host_memory, CU_DEVICE_ATTRIBUTE_CAN_MAP_HOST_MEMORY, dev));
    CHECK_CU(cuDeviceGetAttribute(&unified_addressing, CU_DEVICE_ATTRIBUTE_UNIFIED_ADDRESSING, dev));

    size_t free_before = 0;
    size_t total_before = 0;
    CHECK_CU(cuMemGetInfo(&free_before, &total_before));

    printf("device=%s\n", name);
    printf("bytes=%zu\n", bytes);
    printf("context_mode=%s\n", using_primary_ctx ? "primary" : "user_ctx_map_host");
    printf("primary_ctx_active_before=%d\n", primary_active);
    printf("primary_ctx_flags_before=0x%x\n", primary_flags);
    printf("ctx_flags=0x%x\n", ctx_flags);
    printf("ctx_has_map_host=%d\n", (ctx_flags & CU_CTX_MAP_HOST) ? 1 : 0);
    printf("can_map_host_memory=%d\n", can_map_host_memory);
    printf("unified_addressing=%d\n", unified_addressing);
    printf("free_before=%zu\n", free_before);
    printf("total_before=%zu\n", total_before);
    printf("env_GREENBOOST_ACTIVE=%s\n", getenv("GREENBOOST_ACTIVE") ? getenv("GREENBOOST_ACTIVE") : "");
    printf("env_GREENBOOST_USE_DMA_BUF=%s\n", getenv("GREENBOOST_USE_DMA_BUF") ? getenv("GREENBOOST_USE_DMA_BUF") : "");
    printf("env_GREENBOOST_NO_HOSTREG=%s\n", getenv("GREENBOOST_NO_HOSTREG") ? getenv("GREENBOOST_NO_HOSTREG") : "");
    printf("env_GREENBOOST_VRAM_HEADROOM_MB=%s\n", getenv("GREENBOOST_VRAM_HEADROOM_MB") ? getenv("GREENBOOST_VRAM_HEADROOM_MB") : "");
    fflush(stdout);

    CUdeviceptr ptr = 0;
    double t0 = now_ms();
    CUresult alloc_res = cuMemAlloc_v2(&ptr, bytes);
    double t1 = now_ms();

    const char *alloc_name = NULL;
    const char *alloc_str = NULL;
    cuGetErrorName(alloc_res, &alloc_name);
    cuGetErrorString(alloc_res, &alloc_str);

    printf("alloc_result=%d\n", (int)alloc_res);
    printf("alloc_result_name=%s\n", alloc_name ? alloc_name : "");
    printf("alloc_result_string=%s\n", alloc_str ? alloc_str : "");
    printf("alloc_ms=%.6f\n", t1 - t0);

    if (alloc_res == CUDA_SUCCESS) {
        CHECK_CU(cuMemsetD8(ptr, 0, bytes));

        unsigned char sample[16];
        memset(sample, 0, sizeof(sample));
        CHECK_CU(cuMemcpyDtoH(sample, ptr, sizeof(sample)));
        unsigned checksum = 0;
        for (int i = 0; i < 16; ++i) checksum += sample[i];
        printf("sample_checksum=%u\n", checksum);

        double t2 = now_ms();
        CHECK_CU(cuMemFree_v2(ptr));
        double t3 = now_ms();
        printf("free_ms=%.6f\n", t3 - t2);
    }

    size_t free_after = 0;
    size_t total_after = 0;
    CHECK_CU(cuMemGetInfo(&free_after, &total_after));
    printf("free_after=%zu\n", free_after);
    printf("total_after=%zu\n", total_after);

    if (using_primary_ctx) {
        CHECK_CU(cuDevicePrimaryCtxRelease(dev));
    } else {
        CHECK_CU(cuCtxDestroy(ctx));
    }
    return 0;
}
