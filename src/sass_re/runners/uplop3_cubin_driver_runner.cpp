#include <cmath>
#include <cstring>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "cubin_driver_common.h"

int main(int argc, char **argv) {
    const CubinCliArgs cli = parse_cubin_cli(argc, argv);
    const int pattern = cli.pattern;
    const char *ctx_mode_env = std::getenv("SASS_RE_CTX_MODE");
    const bool explicit_ctx = ctx_mode_env && std::strcmp(ctx_mode_env, "explicit") == 0;

    std::fprintf(stderr, "preflight: cubin driver context\n");
    CubinDriverContext drv(cli.cubin_path, cli.kernel_name);

    constexpr int threads = 32;
    constexpr int count = 32;
    std::vector<float> in(count, 0.0f);
    std::vector<float> out(count, -1.0f);
    int iterations = 0;

    switch (pattern) {
        case 1:
            iterations = 1;
            for (int i = 0; i < count; ++i) in[i] = 1.0f + 0.125f * static_cast<float>(i);
            break;
        case 2:
            iterations = 13;
            for (int i = 0; i < count; ++i) in[i] = ((i % 5) - 2) * 0.75f;
            break;
        case 3:
            iterations = 29;
            for (int i = 0; i < count; ++i) in[i] = (static_cast<float>((i * i) & 15) - 5.0f) * 0.2f;
            break;
        default:
            iterations = 7;
            for (int i = 0; i < count; ++i) in[i] = static_cast<float>(i) * 0.03125f;
            break;
    }

    CUdeviceptr d_out = 0;
    CUdeviceptr d_in = 0;
    std::fprintf(stderr, "preflight: cuMemAlloc\n");
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(float)), "cuMemAlloc(out)");
    cubin_ck(cuMemAlloc(&d_in, in.size() * sizeof(float)), "cuMemAlloc(in)");
    std::fprintf(stderr, "preflight: cuMemcpyHtoD\n");
    cubin_ck(cuMemcpyHtoD(d_in, in.data(), in.size() * sizeof(float)), "cuMemcpyHtoD(in)");
    cubin_ck(cuMemcpyHtoD(d_out, out.data(), out.size() * sizeof(float)), "cuMemcpyHtoD(out_init)");

    int n = count;
    void *params[] = {&d_out, &d_in, &n, &iterations};
    std::fprintf(stderr, "preflight: cuLaunchKernel\n");
    cubin_ck(cuLaunchKernel(drv.fn, 1, 1, 1, threads, 1, 1, 0, nullptr, params, nullptr), "cuLaunchKernel");
    std::fprintf(stderr, "preflight: cuCtxSynchronize\n");
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    std::fprintf(stderr, "preflight: cuMemcpyDtoH\n");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(float)), "cuMemcpyDtoH(out)");

    double sum = 0.0;
    for (float v : out) sum += static_cast<double>(v);
    std::printf("kernel=%s\n", cli.kernel_name.c_str());
    std::printf("pattern=%d\n", pattern);
    std::printf("iterations=%d\n", iterations);
    std::printf("sum=%.9f\n", sum);
    for (int i = 0; i < 8; ++i) {
        std::printf("out[%d]=%.9f\n", i, static_cast<double>(out[i]));
    }

    cuMemFree(d_out);
    cuMemFree(d_in);
    return 0;
}
