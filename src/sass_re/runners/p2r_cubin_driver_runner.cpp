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

    constexpr int threads = 32;
    constexpr int in_count = 14 * 32;
    std::vector<std::uint32_t> out(threads, 0);
    std::vector<int> in(in_count, 0);
    std::vector<std::uint32_t> seed(threads, 0);

    for (int i = 0; i < in_count; ++i) {
        switch (pattern) {
            case 1:
                in[i] = ((i * 29) ^ 0x55) - 173;
                break;
            case 2:
                in[i] = ((i % 19) - 9) * ((i % 7) + 3);
                break;
            case 3:
                in[i] = ((i * i) & 0x1ff) - 128;
                break;
            default:
                in[i] = (i * 17) - 91;
                break;
        }
    }
    for (int i = 0; i < threads; ++i) {
        switch (pattern) {
            case 1:
                seed[i] = 0x89abcdefu ^ static_cast<std::uint32_t>(i * 0x00110011u);
                break;
            case 2:
                seed[i] = 0xdead0000u ^ static_cast<std::uint32_t>(i * 0x01020304u);
                break;
            case 3:
                seed[i] = 0x31410000u ^ static_cast<std::uint32_t>((31 - i) * 0x00010001u);
                break;
            default:
                seed[i] = 0x12340000u ^ static_cast<std::uint32_t>(i * 0x01010101u);
                break;
        }
    }

    CUdeviceptr d_out = 0;
    CUdeviceptr d_in = 0;
    CUdeviceptr d_seed = 0;
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(std::uint32_t)), "cuMemAlloc(out)");
    cubin_ck(cuMemAlloc(&d_in, in.size() * sizeof(int)), "cuMemAlloc(in)");
    cubin_ck(cuMemAlloc(&d_seed, seed.size() * sizeof(std::uint32_t)), "cuMemAlloc(seed)");
    cubin_ck(cuMemcpyHtoD(d_in, in.data(), in.size() * sizeof(int)), "cuMemcpyHtoD(in)");
    cubin_ck(cuMemcpyHtoD(d_seed, seed.data(), seed.size() * sizeof(std::uint32_t)), "cuMemcpyHtoD(seed)");
    cubin_ck(cuMemsetD32(d_out, 0, out.size()), "cuMemsetD32(out)");

    void *params[] = {&d_out, &d_in, &d_seed};
    launch_fetch_u32(drv.fn, 1, threads, params, out, d_out);

    print_u32_summary(cli.kernel_name, pattern, out);

    cuMemFree(d_out);
    cuMemFree(d_in);
    cuMemFree(d_seed);
    return 0;
}
