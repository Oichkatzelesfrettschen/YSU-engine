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

    constexpr int n_cells = 128;
    constexpr int dirs = 19;
    std::vector<float> in(dirs * n_cells, 0.0f);
    std::vector<float> out(n_cells, 0.0f);
    float tau = 0.8f;

    switch (pattern) {
        case 1:
            tau = 1.1f;
            for (int d = 0; d < dirs; ++d) {
                for (int i = 0; i < n_cells; ++i) {
                    in[d * n_cells + i] = 0.1f * static_cast<float>((d + i) & 7);
                }
            }
            break;
        case 2:
            tau = 1.7f;
            for (int d = 0; d < dirs; ++d) {
                for (int i = 0; i < n_cells; ++i) {
                    in[d * n_cells + i] = ((d * 3 + i * 5) & 15) * 0.03125f;
                }
            }
            break;
        case 3:
            tau = 0.55f;
            for (int d = 0; d < dirs; ++d) {
                for (int i = 0; i < n_cells; ++i) {
                    in[d * n_cells + i] =
                        (static_cast<float>(((d + 1) * (i + 3)) & 31) - 10.0f) * 0.015625f;
                }
            }
            break;
        default:
            tau = 0.8f;
            for (int d = 0; d < dirs; ++d) {
                for (int i = 0; i < n_cells; ++i) {
                    in[d * n_cells + i] = 0.05f * static_cast<float>((d ^ i) & 3);
                }
            }
            break;
    }

    CUdeviceptr d_in = 0;
    CUdeviceptr d_out = 0;
    cubin_ck(cuMemAlloc(&d_in, in.size() * sizeof(float)), "cuMemAlloc(in)");
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(float)), "cuMemAlloc(out)");
    cubin_ck(cuMemcpyHtoD(d_in, in.data(), in.size() * sizeof(float)), "cuMemcpyHtoD(in)");
    cubin_ck(cuMemsetD32(d_out, 0, out.size()), "cuMemsetD32(out)");

    int arg_n_cells = n_cells;
    void *params[] = {&d_out, &d_in, &tau, &arg_n_cells};
    cubin_ck(
        cuLaunchKernel(drv.fn, 1, 1, 1, 128, 1, 1, 0, nullptr, params, nullptr),
        "cuLaunchKernel"
    );
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(float)), "cuMemcpyDtoH(out)");

    print_float_summary(cli.kernel_name, pattern, out);
    std::printf("tau=%.8f\n", tau);
    std::printf("n_cells=%d\n", n_cells);

    cuMemFree(d_out);
    cuMemFree(d_in);
    return 0;
}
