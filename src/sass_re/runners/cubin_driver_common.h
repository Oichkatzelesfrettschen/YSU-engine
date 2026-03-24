#pragma once

#include <cuda.h>

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

inline void cubin_ck(CUresult rc, const char *what) {
    if (rc != CUDA_SUCCESS) {
        const char *name = nullptr;
        const char *msg = nullptr;
        cuGetErrorName(rc, &name);
        cuGetErrorString(rc, &msg);
        std::fprintf(stderr, "%s failed: %s (%s)\n", what, name ? name : "?", msg ? msg : "?");
        std::exit(1);
    }
}

struct CubinDriverContext {
    CUdevice dev = 0;
    CUcontext ctx = nullptr;
    CUmodule mod = nullptr;
    CUfunction fn = nullptr;
    bool explicit_ctx = false;

    CubinDriverContext(const std::string &cubin_path, const std::string &kernel_name) {
        const char *ctx_mode_env = std::getenv("SASS_RE_CTX_MODE");
        explicit_ctx = ctx_mode_env && std::strcmp(ctx_mode_env, "explicit") == 0;

        cubin_ck(cuInit(0), "cuInit");
        cubin_ck(cuDeviceGet(&dev, 0), "cuDeviceGet");

        if (explicit_ctx) {
            CUctxCreateParams params{};
            cubin_ck(cuCtxCreate(&ctx, &params, 0, dev), "cuCtxCreate");
        } else {
            cubin_ck(cuDevicePrimaryCtxRetain(&ctx, dev), "cuDevicePrimaryCtxRetain");
        }
        cubin_ck(cuCtxSetCurrent(ctx), "cuCtxSetCurrent");

        cubin_ck(cuModuleLoad(&mod, cubin_path.c_str()), "cuModuleLoad");
        cubin_ck(cuModuleGetFunction(&fn, mod, kernel_name.c_str()), "cuModuleGetFunction");
    }

    ~CubinDriverContext() {
        if (mod) {
            cuModuleUnload(mod);
        }
        if (ctx) {
            if (explicit_ctx) {
                cuCtxDestroy(ctx);
            } else {
                cuDevicePrimaryCtxRelease(dev);
            }
        }
    }
};

struct CubinCliArgs {
    std::string cubin_path;
    std::string kernel_name;
    int pattern = 0;
};

inline CubinCliArgs parse_cubin_cli(int argc, char **argv) {
    if (argc < 3 || argc > 4) {
        std::fprintf(stderr, "usage: %s <cubin> <kernel_name> [pattern]\n", argv[0]);
        std::exit(2);
    }
    CubinCliArgs args;
    args.cubin_path = argv[1];
    args.kernel_name = argv[2];
    args.pattern = (argc == 4) ? std::atoi(argv[3]) : 0;
    return args;
}

inline void print_u32_summary(const std::string &kernel_name, int pattern, const std::vector<std::uint32_t> &out) {
    std::uint64_t sum = 0;
    for (std::uint32_t v : out) {
        sum += v;
    }
    std::printf("kernel=%s\n", kernel_name.c_str());
    std::printf("pattern=%d\n", pattern);
    std::printf("sum=%llu\n", static_cast<unsigned long long>(sum));
    for (int i = 0; i < 8; ++i) {
        std::printf("out[%d]=0x%08x\n", i, out[i]);
    }
}

inline void launch_fetch_u32(CUfunction fn,
                             unsigned grid_x,
                             unsigned block_x,
                             void **params,
                             std::vector<std::uint32_t> &out,
                             CUdeviceptr d_out) {
    cubin_ck(cuLaunchKernel(fn, grid_x, 1, 1, block_x, 1, 1, 0, nullptr, params, nullptr), "cuLaunchKernel");
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(std::uint32_t)), "cuMemcpyDtoH(out)");
}

inline void print_float_summary(const std::string &kernel_name,
                                int pattern,
                                const std::vector<float> &out,
                                const char *extra_label = nullptr,
                                int extra_value = 0) {
    double sum = 0.0;
    for (float v : out) {
        sum += static_cast<double>(v);
    }
    std::printf("kernel=%s\n", kernel_name.c_str());
    std::printf("pattern=%d\n", pattern);
    if (extra_label) {
        std::printf("%s=%d\n", extra_label, extra_value);
    }
    std::printf("sum=%.9f\n", sum);
    for (int i = 0; i < 8; ++i) {
        std::printf("out[%d]=%.9f\n", i, static_cast<double>(out[i]));
    }
}
