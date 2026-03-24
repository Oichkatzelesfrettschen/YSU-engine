#include <cuda.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

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

static void print_result(const char *label, CUresult res) {
    const char *name = NULL;
    const char *str = NULL;
    cuGetErrorName(res, &name);
    cuGetErrorString(res, &str);
    printf("%s_code=%d\n", label, (int)res);
    printf("%s_name=%s\n", label, name ? name : "");
    printf("%s_string=%s\n", label, str ? str : "");
}

int main(int argc, char **argv) {
    const size_t bytes = (argc > 1) ? strtoull(argv[1], NULL, 10) : (size_t)(512ull * 1024ull * 1024ull);
    const int use_malloc = (getenv("HOSTREG_USE_MALLOC") && getenv("HOSTREG_USE_MALLOC")[0] == '1');
    const int try_mlock = (getenv("HOSTREG_TRY_MLOCK") && getenv("HOSTREG_TRY_MLOCK")[0] == '1');

    CHECK_CU(cuInit(0));

    CUdevice dev;
    CHECK_CU(cuDeviceGet(&dev, 0));

    CUcontext ctx;
    CHECK_CU(cuDevicePrimaryCtxRetain(&ctx, dev));
    CHECK_CU(cuCtxSetCurrent(ctx));

    unsigned int ctx_flags = 0;
    CHECK_CU(cuCtxGetFlags(&ctx_flags));

    int can_map_host_memory = 0;
    CHECK_CU(cuDeviceGetAttribute(&can_map_host_memory, CU_DEVICE_ATTRIBUTE_CAN_MAP_HOST_MEMORY, dev));

    void *ptr = NULL;
    if (use_malloc) {
        ptr = malloc(bytes);
    } else {
        ptr = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (ptr == MAP_FAILED) {
            perror("mmap");
            ptr = NULL;
        }
    }

    printf("bytes=%zu\n", bytes);
    printf("allocator=%s\n", use_malloc ? "malloc" : "mmap_anon");
    printf("ctx_flags=0x%x\n", ctx_flags);
    printf("ctx_has_map_host=%d\n", (ctx_flags & CU_CTX_MAP_HOST) ? 1 : 0);
    printf("can_map_host_memory=%d\n", can_map_host_memory);
    printf("ptr=%p\n", ptr);

    if (!ptr) {
        CHECK_CU(cuDevicePrimaryCtxRelease(dev));
        return 2;
    }

    memset(ptr, 0, bytes < 4096 ? bytes : 4096);

    if (try_mlock) {
        int rc = mlock(ptr, bytes);
        printf("mlock_rc=%d\n", rc);
    }

    CUresult reg = cuMemHostRegister(ptr, bytes, CU_MEMHOSTREGISTER_DEVICEMAP);
    print_result("host_register", reg);

    if (reg == CUDA_SUCCESS) {
        CUdeviceptr dptr = 0;
        CUresult map = cuMemHostGetDevicePointer(&dptr, ptr, 0);
        print_result("host_get_device_pointer", map);
        printf("device_ptr=0x%llx\n", (unsigned long long)dptr);
        if (map == CUDA_SUCCESS) {
            (void)cuMemHostUnregister(ptr);
        }
    }

    if (use_malloc) {
        free(ptr);
    } else {
        munmap(ptr, bytes);
    }

    CHECK_CU(cuDevicePrimaryCtxRelease(dev));
    return 0;
}
