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

    constexpr int lanes = 32;
    constexpr int out_count = 4 * lanes;
    constexpr int src_bytes = 256;
    std::vector<float> out(out_count, 0.0f);
    std::vector<float> a_in(4 * lanes, 0.0f);
    std::vector<float> b_in(2 * lanes, 0.0f);
    std::vector<unsigned char> src(src_bytes, 0);

    int tiles = 2;
    int stride = 32;
    int tail_mask = 0x55;
    int stage_mask = 0x3;

    switch (pattern) {
        case 1:
            tiles = 3;
            stride = 32;
            tail_mask = 0x2b;
            stage_mask = 0x5;
            break;
        case 2:
            tiles = 4;
            stride = 16;
            tail_mask = 0x7f;
            stage_mask = 0xa;
            break;
        case 3:
            tiles = 1;
            stride = 48;
            tail_mask = 0x11;
            stage_mask = 0x9;
            break;
        default:
            if (pattern >= 100) {
                const std::uint32_t seed = static_cast<std::uint32_t>(pattern);
                tiles = 1 + static_cast<int>(mix32(seed ^ 0x11111111u) % 4u);
                switch (mix32(seed ^ 0x22222222u) % 3u) {
                    case 0:
                        stride = 16;
                        break;
                    case 1:
                        stride = 32;
                        break;
                    default:
                        stride = 48;
                        break;
                }
                tail_mask = static_cast<int>(mix32(seed ^ 0x33333333u) & 0x7fu);
                stage_mask = static_cast<int>(mix32(seed ^ 0x44444444u) & 0x0fu);
                if (tail_mask == 0) tail_mask = 0x1;
                if (stage_mask == 0) stage_mask = 0x1;
            }
            break;
    }

    for (int i = 0; i < static_cast<int>(a_in.size()); ++i) {
        a_in[i] = 0.25f + 0.03125f * static_cast<float>((i + pattern * 3) & 15);
    }
    for (int i = 0; i < static_cast<int>(b_in.size()); ++i) {
        b_in[i] = 0.5f + 0.0625f * static_cast<float>((i * 3 + pattern) & 7);
    }
    for (int i = 0; i < static_cast<int>(src.size()); ++i) {
        src[i] = static_cast<unsigned char>((i * 5 + pattern * 11) & 0xff);
    }

    CUdeviceptr d_out = 0;
    CUdeviceptr d_a = 0;
    CUdeviceptr d_b = 0;
    CUdeviceptr d_src = 0;
    cubin_ck(cuMemAlloc(&d_out, out.size() * sizeof(float)), "cuMemAlloc(out)");
    cubin_ck(cuMemAlloc(&d_a, a_in.size() * sizeof(float)), "cuMemAlloc(a)");
    cubin_ck(cuMemAlloc(&d_b, b_in.size() * sizeof(float)), "cuMemAlloc(b)");
    cubin_ck(cuMemAlloc(&d_src, src.size()), "cuMemAlloc(src)");
    cubin_ck(cuMemsetD32(d_out, 0, out.size()), "cuMemsetD32(out)");
    cubin_ck(cuMemcpyHtoD(d_a, a_in.data(), a_in.size() * sizeof(float)), "cuMemcpyHtoD(a)");
    cubin_ck(cuMemcpyHtoD(d_b, b_in.data(), b_in.size() * sizeof(float)), "cuMemcpyHtoD(b)");
    cubin_ck(cuMemcpyHtoD(d_src, src.data(), src.size()), "cuMemcpyHtoD(src)");

    void *params[] = {
        &d_out, &d_a, &d_b, &d_src, &tiles, &stride, &tail_mask, &stage_mask
    };
    cubin_ck(
        cuLaunchKernel(drv.fn, 1, 1, 1, lanes, 1, 1, 0, nullptr, params, nullptr),
        "cuLaunchKernel"
    );
    cubin_ck(cuCtxSynchronize(), "cuCtxSynchronize");
    cubin_ck(cuMemcpyDtoH(out.data(), d_out, out.size() * sizeof(float)), "cuMemcpyDtoH(out)");

    print_float_summary(cli.kernel_name, pattern, out);
    std::printf("tiles=%d\n", tiles);
    std::printf("stride=%d\n", stride);
    std::printf("tail_mask=0x%x\n", tail_mask);
    std::printf("stage_mask=0x%x\n", stage_mask);

    cuMemFree(d_src);
    cuMemFree(d_b);
    cuMemFree(d_a);
    cuMemFree(d_out);
    return 0;
}
