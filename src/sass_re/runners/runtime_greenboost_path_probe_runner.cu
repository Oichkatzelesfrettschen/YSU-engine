#include <cuda.h>

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "/usr/share/greenboost/greenboost_ioctl.h"

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
    const char *mode = (argc > 1) ? argv[1] : "path_b_direct";
    const size_t bytes = (argc > 2) ? strtoull(argv[2], NULL, 10) : (size_t)(512ull * 1024ull * 1024ull);

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

    printf("mode=%s\n", mode);
    printf("bytes=%zu\n", bytes);
    printf("ctx_flags=0x%x\n", ctx_flags);
    printf("ctx_has_map_host=%d\n", (ctx_flags & CU_CTX_MAP_HOST) ? 1 : 0);
    printf("can_map_host_memory=%d\n", can_map_host_memory);

    void *ptr = NULL;
    int fd = -1;
    int dmabuf_fd = -1;
    CUresult reg = CUDA_SUCCESS;

    if (strcmp(mode, "path_a_direct") == 0) {
        ptr = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (ptr == MAP_FAILED) {
            perror("mmap");
            ptr = NULL;
        }
        printf("mapped_ptr=%p\n", ptr);
        fd = open("/dev/greenboost", O_RDWR);
        printf("dev_greenboost_fd=%d\n", fd);
        if (fd < 0) {
            printf("open_errno=%d\n", errno);
            perror("open /dev/greenboost");
            goto cleanup;
        }

        struct gb_pin_req req;
        memset(&req, 0, sizeof(req));
        req.vaddr = (uint64_t)(uintptr_t)ptr;
        req.size = bytes;
        req.flags = GB_ALLOC_WEIGHTS;
        req.fd = -1;

        int rc = ioctl(fd, GB_IOCTL_PIN_USER_PTR, &req);
        printf("pin_user_ptr_rc=%d\n", rc);
        printf("pin_user_ptr_errno=%d\n", rc < 0 ? errno : 0);
        if (rc < 0) {
            perror("GB_IOCTL_PIN_USER_PTR");
            goto cleanup;
        }
        dmabuf_fd = req.fd;
        printf("dmabuf_fd=%d\n", dmabuf_fd);
    } else if (strcmp(mode, "path_b_direct") == 0) {
#ifdef MAP_HUGETLB
        ptr = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_HUGE_2MB, -1, 0);
        if (ptr == MAP_FAILED) {
            ptr = NULL;
        }
#endif
        if (!ptr) {
            ptr = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (ptr == MAP_FAILED) {
                perror("mmap");
                ptr = NULL;
            }
        }
        printf("mapped_ptr=%p\n", ptr);
    } else {
        fprintf(stderr, "Unknown mode: %s\n", mode);
        goto cleanup;
    }

    if (!ptr) {
        goto cleanup;
    }

    memset(ptr, 0, bytes < 4096 ? bytes : 4096);

    reg = cuMemHostRegister(ptr, bytes, CU_MEMHOSTREGISTER_DEVICEMAP);
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

cleanup:
    if (ptr) {
        munmap(ptr, bytes);
    }
    if (dmabuf_fd >= 0) {
        close(dmabuf_fd);
    }
    if (fd >= 0) {
        close(fd);
    }
    CHECK_CU(cuDevicePrimaryCtxRelease(dev));
    return 0;
}
