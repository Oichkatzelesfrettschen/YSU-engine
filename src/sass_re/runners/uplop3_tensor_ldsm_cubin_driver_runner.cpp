#include <cuda_fp16.h>

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "cubin_driver_common.h"

static __half hf(float x) {
    return __float2half_rn(x);
}

int main(int argc, char **argv) {
    const CubinCliArgs cli = parse_cubin_cli(argc, argv);
    const int pattern = cli.pattern;
    CubinDriverContext drv(cli.cubin_path, cli.kernel_name);

    constexpr int kTiles = 2;
    constexpr int tileElems = 16 * 16;
    constexpr int inputElems = kTiles * tileElems;
    std::vector<__half> a(inputElems);
    std::vector<__half> b(inputElems);
    std::vector<__half> out(tileElems, hf(-1.0f));

    for (int i = 0; i < inputElems; ++i) {
        float av = 0.0f;
        float bv = 0.0f;
        switch (pattern) {
            case 1:
                av = 1.0f + static_cast<float>(i & 7) * 0.125f;
                bv = 0.5f + static_cast<float>((i * 3) & 7) * 0.0625f;
                break;
            case 2:
                av = static_cast<float>((i % 11) - 5) * 0.25f;
                bv = static_cast<float>((i % 13) - 6) * 0.125f;
                break;
            case 3:
                av = static_cast<float>(((i * i) & 15) - 7) * 0.2f;
                bv = static_cast<float>(((i * 5) & 15) - 4) * 0.15f;
                break;
            default:
                av = static_cast<float>(i & 15) * 0.03125f;
                bv = static_cast<float>((i * 7) & 15) * 0.03125f;
                break;
        }
        a[i] = hf(av);
        b[i] = hf(bv);
    }

    CUdeviceptr d_a = 0;
    CUdeviceptr d_b = 0;
    CUdeviceptr d_out = 0;
    cubin_ck(cuMemAlloc(&d_a, a.size() * sizeof(__half)), "cuMemAlloc(a)");
    cubin_ck(cuMemAlloc(&d_b, b.size() * sizeof(__half)), "cuMemAlloc(b)");
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(__half)), "cuMemAlloc(out)");
    cubin_ck(cuMemcpyHtoD(d_a, a.data(), a.size() * sizeof(__half)), "cuMemcpyHtoD(a)");
    cubin_ck(cuMemcpyHtoD(d_b, b.data(), b.size() * sizeof(__half)), "cuMemcpyHtoD(b)");
    cubin_ck(cuMemcpyHtoD(d_out, out.data(), out.size() * sizeof(__half)), "cuMemcpyHtoD(out)");

    int arg_tiles = kTiles;
    void *params[] = {&d_out, &d_a, &d_b, &arg_tiles};
    cubin_ck(cuLaunchKernel(drv.fn, 1, 1, 1, 32, 1, 1, 0, nullptr, params, nullptr), "cuLaunchKernel");
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(__half)), "cuMemcpyDtoH(out)");

    double sum = 0.0;
    for (const __half &v : out) sum += static_cast<double>(__half2float(v));
    std::printf("kernel=%s\n", cli.kernel_name.c_str());
    std::printf("pattern=%d\n", pattern);
    std::printf("k_tiles=%d\n", kTiles);
    std::printf("sum=%.9f\n", sum);
    for (int i = 0; i < 8; ++i) {
        std::printf("out[%d]=%.9f\n", i, static_cast<double>(__half2float(out[i])));
    }

    cuMemFree(d_out);
    cuMemFree(d_b);
    cuMemFree(d_a);
    return 0;
}
