#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "cubin_driver_common.h"

int main(int argc, char **argv) {
    const CubinCliArgs cli = parse_cubin_cli(argc, argv);
    const int pattern = cli.pattern;
    CubinDriverContext drv(cli.cubin_path, cli.kernel_name);

    constexpr int threads = 128;
    constexpr int count = 128;
    std::vector<float> in(count, 0.0f);
    std::vector<float> out(count, -1.0f);
    int radius = 0;

    switch (pattern) {
        case 1:
            radius = 1;
            for (int i = 0; i < count; ++i) in[i] = 0.125f * static_cast<float>(i);
            break;
        case 2:
            radius = 3;
            for (int i = 0; i < count; ++i) in[i] = ((i % 9) - 4) * 0.5f;
            break;
        case 3:
            radius = 7;
            for (int i = 0; i < count; ++i) in[i] = (static_cast<float>((i * 17) & 31) - 10.0f) * 0.0625f;
            break;
        default:
            radius = 5;
            for (int i = 0; i < count; ++i) in[i] = static_cast<float>(i) * 0.03125f;
            break;
    }

    CUdeviceptr d_out = 0;
    CUdeviceptr d_in = 0;
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(float)), "cuMemAlloc(out)");
    cubin_ck(cuMemAlloc(&d_in, in.size() * sizeof(float)), "cuMemAlloc(in)");
    cubin_ck(cuMemcpyHtoD(d_in, in.data(), in.size() * sizeof(float)), "cuMemcpyHtoD(in)");
    cubin_ck(cuMemcpyHtoD(d_out, out.data(), out.size() * sizeof(float)), "cuMemcpyHtoD(out_init)");

    int n = count;
    void *params[] = {&d_out, &d_in, &n, &radius};
    unsigned shared_bytes = static_cast<unsigned>((threads + 2 * radius) * sizeof(float));
    cubin_ck(cuLaunchKernel(drv.fn, 1, 1, 1, threads, 1, 1, shared_bytes, nullptr, params, nullptr), "cuLaunchKernel");
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(float)), "cuMemcpyDtoH(out)");

    print_float_summary(cli.kernel_name, pattern, out, "radius", radius);

    cuMemFree(d_out);
    cuMemFree(d_in);
    return 0;
}
