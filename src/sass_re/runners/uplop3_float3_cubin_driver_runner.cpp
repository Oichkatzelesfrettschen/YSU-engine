#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "cubin_driver_common.h"

int main(int argc, char **argv) {
    const CubinCliArgs cli = parse_cubin_cli(argc, argv);
    const int pattern = cli.pattern;
    CubinDriverContext drv(cli.cubin_path, cli.kernel_name);

    constexpr int n = 256;
    std::vector<float> in(n, 0.0f);
    std::vector<float> out(n, -1.0f);

    switch (pattern) {
        case 1:
            for (int i = 0; i < n; ++i) in[i] = 1.0f + static_cast<float>(i & 31) * 0.0625f;
            break;
        case 2:
            for (int i = 0; i < n; ++i) in[i] = ((i % 9) - 4) * 0.5f;
            break;
        case 3:
            for (int i = 0; i < n; ++i) in[i] = (static_cast<float>((i * 7) & 15) - 6.0f) * 0.25f;
            break;
        default:
            for (int i = 0; i < n; ++i) in[i] = static_cast<float>(i) * 0.03125f;
            break;
    }

    CUdeviceptr d_in = 0;
    CUdeviceptr d_out = 0;
    cubin_ck(cuMemAlloc(&d_in, in.size() * sizeof(float)), "cuMemAlloc(in)");
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(float)), "cuMemAlloc(out)");
    cubin_ck(cuMemcpyHtoD(d_in, in.data(), in.size() * sizeof(float)), "cuMemcpyHtoD(in)");
    cubin_ck(cuMemcpyHtoD(d_out, out.data(), out.size() * sizeof(float)), "cuMemcpyHtoD(out)");

    int arg_n = n;
    void *params[] = {&d_out, &d_in, &arg_n};
    cubin_ck(cuLaunchKernel(drv.fn, 2, 1, 1, 128, 1, 1, 0, nullptr, params, nullptr), "cuLaunchKernel");
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(float)), "cuMemcpyDtoH(out)");

    print_float_summary(cli.kernel_name, pattern, out);

    cuMemFree(d_out);
    cuMemFree(d_in);
    return 0;
}
