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

    std::uint64_t initial = 0;
    int iters = 16;

    switch (pattern) {
        case 1:
            initial = 5;
            iters = 1;
            break;
        case 2:
            initial = 123;
            iters = 7;
            break;
        case 3:
            initial = 0xffffULL;
            iters = 31;
            break;
        default:
            initial = 0;
            iters = 16;
            break;
    }

    CUdeviceptr d_counter = 0;
    cubin_ck(cuMemAlloc(&d_counter, sizeof(std::uint64_t)), "cuMemAlloc(counter)");
    cubin_ck(
        cuMemcpyHtoD(d_counter, &initial, sizeof(initial)),
        "cuMemcpyHtoD(counter)"
    );

    void *params[] = {&d_counter, &iters};
    cubin_ck(
        cuLaunchKernel(drv.fn, 1, 1, 1, 128, 1, 1, 0, nullptr, params, nullptr),
        "cuLaunchKernel"
    );
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");

    std::uint64_t out = 0;
    cubin_ck(
        cuMemcpyDtoH(&out, d_counter, sizeof(out)),
        "cuMemcpyDtoH(counter)"
    );

    std::printf("kernel=%s\n", cli.kernel_name.c_str());
    std::printf("pattern=%d\n", pattern);
    std::printf("initial=%llu\n", static_cast<unsigned long long>(initial));
    std::printf("iters=%d\n", iters);
    std::printf("counter=%llu\n", static_cast<unsigned long long>(out));

    cuMemFree(d_counter);
    return 0;
}
