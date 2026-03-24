#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "cubin_driver_common.h"

static std::uint32_t mix32(std::uint32_t x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

int main(int argc, char **argv) {
    const CubinCliArgs cli = parse_cubin_cli(argc, argv);
    const int pattern = cli.pattern;
    CubinDriverContext drv(cli.cubin_path, cli.kernel_name);

    constexpr int threads = 128;
    constexpr int count = 128;
    std::vector<std::uint32_t> out(count, 0);
    std::uint32_t a, b, c, d, e, f;

    switch (pattern) {
        case 1:
            a = 0x00000001u; b = 0x00000002u; c = 0x00000010u; d = 0x00000008u; e = 0u; f = 0x8u;
            break;
        case 2:
            a = 0x11111111u; b = 0x22222220u; c = 0x01020304u; d = 0x11223344u; e = 0x000000ffu; f = 0x0000000fu;
            break;
        case 3:
            a = 0xdeadbeefu; b = 0x13579bdfu; c = 0x00000003u; d = 0x00000004u; e = 0x00000008u; f = 0x00000000u;
            break;
        default:
            if (pattern >= 100) {
                const std::uint32_t seed = static_cast<std::uint32_t>(pattern);
                a = mix32(seed ^ 0x13579bdfu);
                b = mix32(seed ^ 0x2468ace0u) & 0xfffffff0u;
                c = mix32(seed ^ 0x0f0f0f0fu);
                d = mix32(seed ^ 0xf0f0f0f0u);
                e = mix32(seed ^ 0x55aa55aau) & 0x000000ffu;
                f = mix32(seed ^ 0xaa55aa55u) & 0x0000000fu;
            } else {
                a = 0x00000003u; b = 0x00000000u; c = 0x00000009u; d = 0x00000004u; e = 0x00000000u; f = 0x00000008u;
            }
            break;
    }

    CUdeviceptr d_out = 0;
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(std::uint32_t)), "cuMemAlloc(out)");
    cubin_ck(cuMemsetD32(d_out, 0, out.size()), "cuMemsetD32(out)");

    void *params[] = {&d_out, &a, &b, &c, &d, &e, &f};
    launch_fetch_u32(drv.fn, 1, threads, params, out, d_out);

    print_u32_summary(cli.kernel_name, pattern, out);

    cuMemFree(d_out);
    return 0;
}
