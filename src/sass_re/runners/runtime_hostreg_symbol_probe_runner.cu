#include <cuda.h>

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

typedef CUresult (*pfn_cuMemHostRegister_raw)(void *, size_t, unsigned int);
typedef CUresult (*pfn_cuMemHostGetDevicePointer_raw)(CUdeviceptr *, void *, unsigned int);
typedef CUresult (*pfn_cuMemHostUnregister_raw)(void *);

static void print_result(const char *label, CUresult res) {
    const char *name = NULL;
    const char *str = NULL;
    cuGetErrorName(res, &name);
    cuGetErrorString(res, &str);
    printf("%s_code=%d\n", label, (int)res);
    printf("%s_name=%s\n", label, name ? name : "");
    printf("%s_string=%s\n", label, str ? str : "");
}

static int run_case(const char *label,
                    pfn_cuMemHostRegister_raw host_register_fn,
                    pfn_cuMemHostGetDevicePointer_raw host_get_device_ptr_fn,
                    pfn_cuMemHostUnregister_raw host_unregister_fn,
                    size_t bytes) {
    void *ptr = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ptr == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    memset(ptr, 0, bytes < 4096 ? bytes : 4096);

    printf("[%s]\n", label);
    printf("ptr=%p\n", ptr);
    CUresult reg = host_register_fn(ptr, bytes, CU_MEMHOSTREGISTER_DEVICEMAP);
    print_result("host_register", reg);
    if (reg == CUDA_SUCCESS) {
        CUdeviceptr dptr = 0;
        CUresult map = host_get_device_ptr_fn(&dptr, ptr, 0);
        print_result("host_get_device_pointer", map);
        printf("device_ptr=0x%llx\n", (unsigned long long)dptr);
        (void)host_unregister_fn(ptr);
    }
    printf("\n");
    munmap(ptr, bytes);
    return 0;
}

int main(int argc, char **argv) {
    const size_t bytes = (argc > 1) ? strtoull(argv[1], NULL, 10) : (size_t)(512ull * 1024ull * 1024ull);

    if (cuInit(0) != CUDA_SUCCESS) {
        fprintf(stderr, "cuInit failed\n");
        return 1;
    }

    CUdevice dev;
    if (cuDeviceGet(&dev, 0) != CUDA_SUCCESS) {
        fprintf(stderr, "cuDeviceGet failed\n");
        return 1;
    }

    CUcontext ctx;
    if (cuDevicePrimaryCtxRetain(&ctx, dev) != CUDA_SUCCESS) {
        fprintf(stderr, "cuDevicePrimaryCtxRetain failed\n");
        return 1;
    }
    if (cuCtxSetCurrent(ctx) != CUDA_SUCCESS) {
        fprintf(stderr, "cuCtxSetCurrent failed\n");
        return 1;
    }

    unsigned int ctx_flags = 0;
    cuCtxGetFlags(&ctx_flags);
    printf("bytes=%zu\n", bytes);
    printf("ctx_flags=0x%x\n", ctx_flags);
    printf("ctx_has_map_host=%d\n", (ctx_flags & CU_CTX_MAP_HOST) ? 1 : 0);

    void *libcuda = dlopen("libcuda.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (!libcuda) {
        fprintf(stderr, "dlopen libcuda.so.1 failed\n");
        return 1;
    }

    pfn_cuMemHostRegister_raw reg_base =
        (pfn_cuMemHostRegister_raw)dlsym(libcuda, "cuMemHostRegister");
    pfn_cuMemHostGetDevicePointer_raw get_base =
        (pfn_cuMemHostGetDevicePointer_raw)dlsym(libcuda, "cuMemHostGetDevicePointer");
    pfn_cuMemHostUnregister_raw unreg_base =
        (pfn_cuMemHostUnregister_raw)dlsym(libcuda, "cuMemHostUnregister");

    pfn_cuMemHostRegister_raw reg_v2 =
        (pfn_cuMemHostRegister_raw)dlsym(libcuda, "cuMemHostRegister_v2");
    pfn_cuMemHostGetDevicePointer_raw get_v2 =
        (pfn_cuMemHostGetDevicePointer_raw)dlsym(libcuda, "cuMemHostGetDevicePointer_v2");
    pfn_cuMemHostUnregister_raw unreg_v2 =
        (pfn_cuMemHostUnregister_raw)dlsym(libcuda, "cuMemHostUnregister");

    printf("sym_cuMemHostRegister=%p\n", (void *)reg_base);
    printf("sym_cuMemHostGetDevicePointer=%p\n", (void *)get_base);
    printf("sym_cuMemHostRegister_v2=%p\n", (void *)reg_v2);
    printf("sym_cuMemHostGetDevicePointer_v2=%p\n", (void *)get_v2);
    printf("\n");

    if (reg_base && get_base && unreg_base) {
        run_case("base_symbols", reg_base, get_base, unreg_base, bytes);
    }
    if (reg_v2 && get_v2 && unreg_v2) {
        run_case("v2_symbols", reg_v2, get_v2, unreg_v2, bytes);
    }

    cuDevicePrimaryCtxRelease(dev);
    return 0;
}
