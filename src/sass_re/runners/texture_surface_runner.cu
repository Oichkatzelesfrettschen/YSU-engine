#include <cuda_runtime.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

#include "../probes/texture_surface/probe_tmu_behavior.cu"

#define CHECK_CUDA(expr) do { \
    cudaError_t err__ = (expr); \
    if (err__ != cudaSuccess) { \
        fprintf(stderr, "CUDA error: %s (%d) at %s:%d\n", \
                cudaGetErrorString(err__), (int)err__, __FILE__, __LINE__); \
        return 1; \
    } \
} while (0)

static const float kEps = 1.0e-3f;

static bool nearly_equal(float a, float b) {
    return fabsf(a - b) < kEps;
}

static int wrap_index(int i, int n) {
    int m = i % n;
    if (m < 0) m += n;
    return m;
}

static int mirror_index(int i, int n) {
    if (n <= 1) return 0;
    int period = 2 * n;
    int m = i % period;
    if (m < 0) m += period;
    if (m < n) return m;
    return period - 1 - m;
}

static float fetch_1d(const std::vector<float> &data, int i, cudaTextureAddressMode mode) {
    int n = (int)data.size();
    if (mode == cudaAddressModeClamp) {
        if (i < 0) i = 0;
        if (i >= n) i = n - 1;
        return data[(size_t)i];
    }
    if (mode == cudaAddressModeBorder) {
        if (i < 0 || i >= n) return 0.0f;
        return data[(size_t)i];
    }
    if (mode == cudaAddressModeWrap) {
        return data[(size_t)wrap_index(i, n)];
    }
    return data[(size_t)mirror_index(i, n)];
}

static float tex1d_point_oracle(const std::vector<float> &data,
                                float coord,
                                cudaTextureAddressMode mode) {
    int n = (int)data.size();
    float x = coord * (float)n - 0.5f;
    int i = (int)floorf(x + 0.5f);
    return fetch_1d(data, i, mode);
}

static float tex1d_linear_oracle(const std::vector<float> &data,
                                 float coord,
                                 cudaTextureAddressMode mode) {
    int n = (int)data.size();
    float x = coord * (float)n - 0.5f;
    int i = (int)floorf(x);
    float alpha = x - floorf(x);
    float a = fetch_1d(data, i, mode);
    float b = fetch_1d(data, i + 1, mode);
    return a + alpha * (b - a);
}

static float fetch_2d(const std::vector<float> &data,
                      int w,
                      int h,
                      int x,
                      int y,
                      cudaTextureAddressMode mode) {
    if (mode == cudaAddressModeClamp) {
        if (x < 0) x = 0;
        if (x >= w) x = w - 1;
        if (y < 0) y = 0;
        if (y >= h) y = h - 1;
        return data[(size_t)y * (size_t)w + (size_t)x];
    }
    if (mode == cudaAddressModeBorder) {
        if (x < 0 || x >= w || y < 0 || y >= h) return 0.0f;
        return data[(size_t)y * (size_t)w + (size_t)x];
    }
    if (mode == cudaAddressModeWrap) {
        return data[(size_t)wrap_index(y, h) * (size_t)w + (size_t)wrap_index(x, w)];
    }
    return data[(size_t)mirror_index(y, h) * (size_t)w + (size_t)mirror_index(x, w)];
}

static float tex2d_point_oracle(const std::vector<float> &data,
                                int w,
                                int h,
                                float u,
                                float v,
                                cudaTextureAddressMode mode) {
    float x = u * (float)w - 0.5f;
    float y = v * (float)h - 0.5f;
    int ix = (int)floorf(x + 0.5f);
    int iy = (int)floorf(y + 0.5f);
    return fetch_2d(data, w, h, ix, iy, mode);
}

static float tex2d_linear_oracle(const std::vector<float> &data,
                                 int w,
                                 int h,
                                 float u,
                                 float v,
                                 cudaTextureAddressMode mode) {
    float x = u * (float)w - 0.5f;
    float y = v * (float)h - 0.5f;
    int ix = (int)floorf(x);
    int iy = (int)floorf(y);
    float ax = x - floorf(x);
    float ay = y - floorf(y);
    float v00 = fetch_2d(data, w, h, ix, iy, mode);
    float v10 = fetch_2d(data, w, h, ix + 1, iy, mode);
    float v01 = fetch_2d(data, w, h, ix, iy + 1, mode);
    float v11 = fetch_2d(data, w, h, ix + 1, iy + 1, mode);
    float ix0 = v00 + ax * (v10 - v00);
    float ix1 = v01 + ax * (v11 - v01);
    return ix0 + ay * (ix1 - ix0);
}

static float fetch_3d(const std::vector<float> &data,
                      int w,
                      int h,
                      int d,
                      int x,
                      int y,
                      int z) {
    if (x < 0) x = 0;
    if (x >= w) x = w - 1;
    if (y < 0) y = 0;
    if (y >= h) y = h - 1;
    if (z < 0) z = 0;
    if (z >= d) z = d - 1;
    return data[(size_t)z * (size_t)w * (size_t)h + (size_t)y * (size_t)w + (size_t)x];
}

static float tex3d_linear_oracle(const std::vector<float> &data,
                                 int w,
                                 int h,
                                 int d,
                                 float u,
                                 float v,
                                 float q) {
    float x = u * (float)w - 0.5f;
    float y = v * (float)h - 0.5f;
    float z = q * (float)d - 0.5f;
    int ix = (int)floorf(x);
    int iy = (int)floorf(y);
    int iz = (int)floorf(z);
    float ax = x - floorf(x);
    float ay = y - floorf(y);
    float az = z - floorf(z);
    float c000 = fetch_3d(data, w, h, d, ix, iy, iz);
    float c100 = fetch_3d(data, w, h, d, ix + 1, iy, iz);
    float c010 = fetch_3d(data, w, h, d, ix, iy + 1, iz);
    float c110 = fetch_3d(data, w, h, d, ix + 1, iy + 1, iz);
    float c001 = fetch_3d(data, w, h, d, ix, iy, iz + 1);
    float c101 = fetch_3d(data, w, h, d, ix + 1, iy, iz + 1);
    float c011 = fetch_3d(data, w, h, d, ix, iy + 1, iz + 1);
    float c111 = fetch_3d(data, w, h, d, ix + 1, iy + 1, iz + 1);
    float x00 = c000 + ax * (c100 - c000);
    float x10 = c010 + ax * (c110 - c010);
    float x01 = c001 + ax * (c101 - c001);
    float x11 = c011 + ax * (c111 - c011);
    float y0 = x00 + ay * (x10 - x00);
    float y1 = x01 + ay * (x11 - x01);
    return y0 + az * (y1 - y0);
}

static int expect_close(const char *label,
                        const std::vector<float> &got,
                        const std::vector<float> &expected) {
    if (got.size() != expected.size()) {
        fprintf(stderr, "%s: size mismatch\n", label);
        return 2;
    }
    for (size_t i = 0; i < got.size(); ++i) {
        if (!nearly_equal(got[i], expected[i])) {
            fprintf(stderr, "%s mismatch at %zu: got=%f expected=%f\n",
                    label, i, got[i], expected[i]);
            return 2;
        }
    }
    printf("%s: OK (%zu values)\n", label, got.size());
    return 0;
}

static int expect_affine(const char *label,
                         const std::vector<float> &got,
                         const std::vector<float> &src,
                         float bias) {
    if (got.size() != src.size()) return 2;
    for (size_t i = 0; i < got.size(); ++i) {
        float expected = src[i] + bias;
        if (!nearly_equal(got[i], expected)) {
            fprintf(stderr, "%s mismatch at %zu: got=%f expected=%f\n",
                    label, i, got[i], expected);
            return 2;
        }
    }
    printf("%s: OK (%zu values)\n", label, got.size());
    return 0;
}

static int make_linear_texture(const std::vector<float> &data, cudaTextureObject_t *tex, float **d_ptr) {
    cudaResourceDesc res = {};
    cudaTextureDesc desc = {};
    CHECK_CUDA(cudaMalloc((void **)d_ptr, data.size() * sizeof(float)));
    CHECK_CUDA(cudaMemcpy(*d_ptr, data.data(), data.size() * sizeof(float), cudaMemcpyHostToDevice));
    res.resType = cudaResourceTypeLinear;
    res.res.linear.devPtr = *d_ptr;
    res.res.linear.sizeInBytes = data.size() * sizeof(float);
    res.res.linear.desc = cudaCreateChannelDesc<float>();
    desc.readMode = cudaReadModeElementType;
    CHECK_CUDA(cudaCreateTextureObject(tex, &res, &desc, NULL));
    return 0;
}

static int make_array_texture_1d(const std::vector<float> &data,
                                 cudaTextureFilterMode filter,
                                 cudaTextureAddressMode mode,
                                 cudaTextureObject_t *tex,
                                 cudaArray_t *array) {
    cudaResourceDesc res = {};
    cudaTextureDesc desc = {};
    cudaChannelFormatDesc channel = cudaCreateChannelDesc<float>();
    CHECK_CUDA(cudaMallocArray(array, &channel, data.size(), 0));
    CHECK_CUDA(cudaMemcpy2DToArray(*array, 0, 0, data.data(),
                                   data.size() * sizeof(float),
                                   data.size() * sizeof(float), 1,
                                   cudaMemcpyHostToDevice));
    res.resType = cudaResourceTypeArray;
    res.res.array.array = *array;
    desc.addressMode[0] = mode;
    desc.filterMode = filter;
    desc.normalizedCoords = 1;
    desc.readMode = cudaReadModeElementType;
    CHECK_CUDA(cudaCreateTextureObject(tex, &res, &desc, NULL));
    return 0;
}

static int make_array_texture_2d(const std::vector<float> &data,
                                 int w,
                                 int h,
                                 cudaTextureFilterMode filter,
                                 cudaTextureAddressMode mode,
                                 cudaTextureObject_t *tex,
                                 cudaArray_t *array) {
    cudaResourceDesc res = {};
    cudaTextureDesc desc = {};
    cudaChannelFormatDesc channel = cudaCreateChannelDesc<float>();
    CHECK_CUDA(cudaMallocArray(array, &channel, w, h, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMemcpy2DToArray(*array, 0, 0, data.data(), (size_t)w * sizeof(float),
                                   (size_t)w * sizeof(float), h, cudaMemcpyHostToDevice));
    res.resType = cudaResourceTypeArray;
    res.res.array.array = *array;
    desc.addressMode[0] = mode;
    desc.addressMode[1] = mode;
    desc.filterMode = filter;
    desc.normalizedCoords = 1;
    desc.readMode = cudaReadModeElementType;
    CHECK_CUDA(cudaCreateTextureObject(tex, &res, &desc, NULL));
    return 0;
}

static int make_array_texture_3d(const std::vector<float> &data,
                                 int w,
                                 int h,
                                 int d,
                                 cudaTextureFilterMode filter,
                                 cudaTextureObject_t *tex,
                                 cudaArray_t *array) {
    cudaExtent extent = make_cudaExtent((size_t)w, (size_t)h, (size_t)d);
    cudaResourceDesc res = {};
    cudaTextureDesc desc = {};
    cudaChannelFormatDesc channel = cudaCreateChannelDesc<float>();
    CHECK_CUDA(cudaMalloc3DArray(array, &channel, extent, cudaArraySurfaceLoadStore));

    cudaMemcpy3DParms params = {};
    params.srcPtr = make_cudaPitchedPtr((void *)data.data(), (size_t)w * sizeof(float), (size_t)w, (size_t)h);
    params.dstArray = *array;
    params.extent = extent;
    params.kind = cudaMemcpyHostToDevice;
    CHECK_CUDA(cudaMemcpy3D(&params));

    res.resType = cudaResourceTypeArray;
    res.res.array.array = *array;
    desc.addressMode[0] = cudaAddressModeClamp;
    desc.addressMode[1] = cudaAddressModeClamp;
    desc.addressMode[2] = cudaAddressModeClamp;
    desc.filterMode = filter;
    desc.normalizedCoords = 1;
    desc.readMode = cudaReadModeElementType;
    CHECK_CUDA(cudaCreateTextureObject(tex, &res, &desc, NULL));
    return 0;
}

static int make_surface(cudaArray_t array, cudaSurfaceObject_t *surf) {
    cudaResourceDesc res = {};
    res.resType = cudaResourceTypeArray;
    res.res.array.array = array;
    CHECK_CUDA(cudaCreateSurfaceObject(surf, &res));
    return 0;
}

static int run_probe_texture_surface(void) {
    std::vector<float> linear_data(2048);
    for (size_t i = 0; i < linear_data.size(); ++i) linear_data[i] = (float)i * 0.125f;
    std::vector<float> tex2d_data(16);
    std::vector<float> tex3d_data(64);
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 4; ++x) {
            tex2d_data[(size_t)y * 4u + (size_t)x] = 0.01f * (float)(y * 4 + x);
        }
    }
    for (int z = 0; z < 4; ++z) {
        for (int y = 0; y < 4; ++y) {
            for (int x = 0; x < 4; ++x) {
                tex3d_data[(size_t)z * 16u + (size_t)y * 4u + (size_t)x] =
                    0.01f * (float)(z * 16 + y * 4 + x);
            }
        }
    }

    float *d_out = NULL;
    float *d_linear = NULL;
    cudaTextureObject_t tex_linear = 0;
    cudaTextureObject_t tex2d = 0;
    cudaTextureObject_t tex3d = 0;
    cudaSurfaceObject_t surf_in = 0;
    cudaSurfaceObject_t surf_out = 0;
    cudaArray_t array2d = NULL;
    cudaArray_t array3d = NULL;
    cudaArray_t surf_in_arr = NULL;
    cudaArray_t surf_out_arr = NULL;

    CHECK_CUDA(cudaMalloc(&d_out, linear_data.size() * sizeof(float)));
    if (make_linear_texture(linear_data, &tex_linear, &d_linear)) return 1;
    if (make_array_texture_2d(tex2d_data, 4, 4, cudaFilterModeLinear, cudaAddressModeClamp, &tex2d, &array2d)) return 1;
    if (make_array_texture_3d(tex3d_data, 4, 4, 4, cudaFilterModeLinear, &tex3d, &array3d)) return 1;

    cudaChannelFormatDesc channel = cudaCreateChannelDesc<float>();
    CHECK_CUDA(cudaMallocArray(&surf_in_arr, &channel, linear_data.size(), 0, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMallocArray(&surf_out_arr, &channel, linear_data.size(), 0, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMemcpy2DToArray(surf_in_arr, 0, 0, linear_data.data(),
                                   linear_data.size() * sizeof(float),
                                   linear_data.size() * sizeof(float), 1,
                                   cudaMemcpyHostToDevice));
    if (make_surface(surf_in_arr, &surf_in)) return 1;
    if (make_surface(surf_out_arr, &surf_out)) return 1;

    probe_tex_1d_float<<<1, 32>>>(d_out, tex_linear, 32);
    probe_tex_2d_float<<<dim3(1, 1, 1), dim3(4, 4, 1)>>>(d_out, tex2d, 4, 4);
    probe_tex_3d_float<<<1, 32>>>(d_out, tex3d, 4, 4, 4);
    probe_tex_chain<<<1, 32>>>(d_out, tex_linear);
    probe_surface_load_store<<<1, 32>>>(surf_in, surf_out, 32);
    probe_tex_multi_fetch<<<1, 128>>>(d_out, tex_linear, 128);
    CHECK_CUDA(cudaDeviceSynchronize());

    cudaDestroySurfaceObject(surf_out);
    cudaDestroySurfaceObject(surf_in);
    cudaFreeArray(surf_out_arr);
    cudaFreeArray(surf_in_arr);
    cudaDestroyTextureObject(tex3d);
    cudaDestroyTextureObject(tex2d);
    cudaDestroyTextureObject(tex_linear);
    cudaFreeArray(array3d);
    cudaFreeArray(array2d);
    cudaFree(d_linear);
    cudaFree(d_out);
    printf("probe_texture_surface: launched\n");
    return 0;
}

static int run_probe_tmu_behavior(void) {
    int rc = 0;

    std::vector<float> data1d = { 1.0f, 2.0f, 4.0f, 8.0f, 16.0f, 32.0f, 64.0f, 128.0f };
    std::vector<float> out1d(data1d.size());
    std::vector<float> expect1d(data1d.size());
    float *d_out = NULL;
    float *d_coords1d = NULL;
    float2 *d_coords2d = NULL;
    cudaTextureObject_t tex1d_point = 0;
    cudaTextureObject_t tex1d_linear = 0;
    cudaArray_t arr1d_point = NULL;
    cudaArray_t arr1d_linear = NULL;
    CHECK_CUDA(cudaMalloc(&d_out, 4096 * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_coords1d, 64 * sizeof(float)));
    CHECK_CUDA(cudaMalloc(&d_coords2d, 64 * sizeof(float2)));
    if (make_array_texture_1d(data1d, cudaFilterModePoint, cudaAddressModeClamp, &tex1d_point, &arr1d_point)) return 1;
    if (make_array_texture_1d(data1d, cudaFilterModeLinear, cudaAddressModeClamp, &tex1d_linear, &arr1d_linear)) return 1;

    tmu_1d_point<<<1, (unsigned)data1d.size()>>>(d_out, tex1d_point, (int)data1d.size());
    CHECK_CUDA(cudaMemcpy(out1d.data(), d_out, data1d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    for (size_t i = 0; i < data1d.size(); ++i) {
        expect1d[i] = tex1d_point_oracle(data1d, ((float)i + 0.25f) / (float)data1d.size(), cudaAddressModeClamp);
    }
    rc |= expect_close("tmu_1d_point", out1d, expect1d);

    tmu_1d_linear<<<1, (unsigned)data1d.size()>>>(d_out, tex1d_linear, (int)data1d.size());
    CHECK_CUDA(cudaMemcpy(out1d.data(), d_out, data1d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    for (size_t i = 0; i < data1d.size(); ++i) {
        expect1d[i] = tex1d_linear_oracle(data1d, ((float)i + 0.75f) / (float)data1d.size(), cudaAddressModeClamp);
    }
    rc |= expect_close("tmu_1d_linear", out1d, expect1d);

    std::vector<float> sample_coords = { -0.25f, 0.10f, 0.90f, 1.25f };
    CHECK_CUDA(cudaMemcpy(d_coords1d, sample_coords.data(), sample_coords.size() * sizeof(float), cudaMemcpyHostToDevice));
    cudaTextureObject_t addr_tex[4] = {};
    cudaArray_t addr_arr[4] = {};
    cudaTextureAddressMode modes[4] = {
        cudaAddressModeClamp,
        cudaAddressModeBorder,
        cudaAddressModeWrap,
        cudaAddressModeMirror,
    };
    const char *mode_names[4] = { "clamp", "border", "wrap", "mirror" };
    for (int m = 0; m < 4; ++m) {
        if (make_array_texture_1d(data1d, cudaFilterModePoint, modes[m], &addr_tex[m], &addr_arr[m])) return 1;
        tmu_1d_sample_coords<<<1, (unsigned)sample_coords.size()>>>(d_out, addr_tex[m], d_coords1d, (int)sample_coords.size());
        CHECK_CUDA(cudaMemcpy(out1d.data(), d_out, sample_coords.size() * sizeof(float), cudaMemcpyDeviceToHost));
        expect1d.resize(sample_coords.size());
        out1d.resize(sample_coords.size());
        for (size_t i = 0; i < sample_coords.size(); ++i) {
            expect1d[i] = tex1d_point_oracle(data1d, sample_coords[i], modes[m]);
        }
        char label[64];
        snprintf(label, sizeof(label), "tmu_1d_addr_%s", mode_names[m]);
        rc |= expect_close(label, out1d, expect1d);
    }

    const int w2 = 4;
    const int h2 = 4;
    std::vector<float> data2d((size_t)w2 * (size_t)h2);
    for (int y = 0; y < h2; ++y) {
        for (int x = 0; x < w2; ++x) {
            data2d[(size_t)y * (size_t)w2 + (size_t)x] = 0.01f * (float)(y * w2 + x);
        }
    }
    std::vector<float> out2d((size_t)w2 * (size_t)h2);
    std::vector<float> expect2d((size_t)w2 * (size_t)h2);
    cudaTextureObject_t tex2d_point = 0;
    cudaTextureObject_t tex2d_linear = 0;
    cudaArray_t arr2d_point = NULL;
    cudaArray_t arr2d_linear = NULL;
    if (make_array_texture_2d(data2d, w2, h2, cudaFilterModePoint, cudaAddressModeClamp, &tex2d_point, &arr2d_point)) return 1;
    if (make_array_texture_2d(data2d, w2, h2, cudaFilterModeLinear, cudaAddressModeClamp, &tex2d_linear, &arr2d_linear)) return 1;

    tmu_2d_point<<<dim3(1, 1, 1), dim3(w2, h2, 1)>>>(d_out, tex2d_point, w2, h2);
    CHECK_CUDA(cudaMemcpy(out2d.data(), d_out, out2d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    for (int y = 0; y < h2; ++y) {
        for (int x = 0; x < w2; ++x) {
            expect2d[(size_t)y * (size_t)w2 + (size_t)x] =
                tex2d_point_oracle(data2d, w2, h2, ((float)x + 0.25f) / (float)w2, ((float)y + 0.75f) / (float)h2,
                                   cudaAddressModeClamp);
        }
    }
    rc |= expect_close("tmu_2d_point", out2d, expect2d);

    tmu_2d_linear<<<dim3(1, 1, 1), dim3(w2, h2, 1)>>>(d_out, tex2d_linear, w2, h2);
    CHECK_CUDA(cudaMemcpy(out2d.data(), d_out, out2d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    for (int y = 0; y < h2; ++y) {
        for (int x = 0; x < w2; ++x) {
            expect2d[(size_t)y * (size_t)w2 + (size_t)x] =
                tex2d_linear_oracle(data2d, w2, h2, ((float)x + 0.75f) / (float)w2, ((float)y + 0.75f) / (float)h2,
                                    cudaAddressModeClamp);
        }
    }
    rc |= expect_close("tmu_2d_linear", out2d, expect2d);

    tmu_2d_manual_bilerp<<<dim3(1, 1, 1), dim3(w2, h2, 1)>>>(d_out, tex2d_point, w2, h2);
    CHECK_CUDA(cudaMemcpy(out2d.data(), d_out, out2d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    rc |= expect_close("tmu_2d_manual_bilerp", out2d, expect2d);

    std::vector<float2> sample_uv = {
        make_float2(-0.25f, 0.10f),
        make_float2(0.10f, 0.10f),
        make_float2(1.25f, 0.40f),
        make_float2(0.60f, 1.40f),
    };
    CHECK_CUDA(cudaMemcpy(d_coords2d, sample_uv.data(), sample_uv.size() * sizeof(float2), cudaMemcpyHostToDevice));
    std::vector<float> out_addr(sample_uv.size());
    std::vector<float> expect_addr(sample_uv.size());
    for (int m = 0; m < 4; ++m) {
        cudaTextureObject_t tex = 0;
        cudaArray_t arr = NULL;
        if (make_array_texture_2d(data2d, w2, h2, cudaFilterModePoint, modes[m], &tex, &arr)) return 1;
        tmu_2d_sample_coords<<<1, (unsigned)sample_uv.size()>>>(d_out, tex, d_coords2d, (int)sample_uv.size());
        CHECK_CUDA(cudaMemcpy(out_addr.data(), d_out, sample_uv.size() * sizeof(float), cudaMemcpyDeviceToHost));
        for (size_t i = 0; i < sample_uv.size(); ++i) {
            expect_addr[i] = tex2d_point_oracle(data2d, w2, h2, sample_uv[i].x, sample_uv[i].y, modes[m]);
        }
        char label[64];
        snprintf(label, sizeof(label), "tmu_2d_addr_%s", mode_names[m]);
        rc |= expect_close(label, out_addr, expect_addr);
        cudaDestroyTextureObject(tex);
        cudaFreeArray(arr);
    }

    const int w3 = 4;
    const int h3 = 4;
    const int d3 = 4;
    std::vector<float> data3d((size_t)w3 * (size_t)h3 * (size_t)d3);
    for (int z = 0; z < d3; ++z) {
        for (int y = 0; y < h3; ++y) {
            for (int x = 0; x < w3; ++x) {
                data3d[(size_t)z * (size_t)w3 * (size_t)h3 + (size_t)y * (size_t)w3 + (size_t)x] =
                    0.01f * (float)(z * w3 * h3 + y * w3 + x);
            }
        }
    }
    std::vector<float> out3d(data3d.size());
    std::vector<float> expect3d(data3d.size());
    cudaTextureObject_t tex3d_point = 0;
    cudaTextureObject_t tex3d_linear = 0;
    cudaArray_t arr3d_point = NULL;
    cudaArray_t arr3d_linear = NULL;
    if (make_array_texture_3d(data3d, w3, h3, d3, cudaFilterModePoint, &tex3d_point, &arr3d_point)) return 1;
    if (make_array_texture_3d(data3d, w3, h3, d3, cudaFilterModeLinear, &tex3d_linear, &arr3d_linear)) return 1;

    tmu_3d_linear<<<1, (unsigned)data3d.size()>>>(d_out, tex3d_linear, w3, h3, d3);
    CHECK_CUDA(cudaMemcpy(out3d.data(), d_out, out3d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    for (int z = 0; z < d3; ++z) {
        for (int y = 0; y < h3; ++y) {
            for (int x = 0; x < w3; ++x) {
                size_t idx = (size_t)z * (size_t)w3 * (size_t)h3 + (size_t)y * (size_t)w3 + (size_t)x;
                expect3d[idx] = tex3d_linear_oracle(data3d, w3, h3, d3,
                                                    ((float)x + 0.75f) / (float)w3,
                                                    ((float)y + 0.75f) / (float)h3,
                                                    ((float)z + 0.75f) / (float)d3);
            }
        }
    }
    rc |= expect_close("tmu_3d_linear", out3d, expect3d);

    tmu_3d_manual_trilerp<<<1, (unsigned)data3d.size()>>>(d_out, tex3d_point, w3, h3, d3);
    CHECK_CUDA(cudaMemcpy(out3d.data(), d_out, out3d.size() * sizeof(float), cudaMemcpyDeviceToHost));
    rc |= expect_close("tmu_3d_manual_trilerp", out3d, expect3d);

    cudaSurfaceObject_t surf1d_in = 0;
    cudaSurfaceObject_t surf1d_out = 0;
    cudaSurfaceObject_t surf2d_in = 0;
    cudaSurfaceObject_t surf2d_out = 0;
    cudaArray_t surf1d_arr_in = NULL;
    cudaArray_t surf1d_arr_out = NULL;
    cudaArray_t surf2d_arr_in = NULL;
    cudaArray_t surf2d_arr_out = NULL;
    cudaChannelFormatDesc channel = cudaCreateChannelDesc<float>();
    CHECK_CUDA(cudaMallocArray(&surf1d_arr_in, &channel, data1d.size(), 0, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMallocArray(&surf1d_arr_out, &channel, data1d.size(), 0, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMemcpy2DToArray(surf1d_arr_in, 0, 0, data1d.data(),
                                   data1d.size() * sizeof(float),
                                   data1d.size() * sizeof(float), 1,
                                   cudaMemcpyHostToDevice));
    if (make_surface(surf1d_arr_in, &surf1d_in)) return 1;
    if (make_surface(surf1d_arr_out, &surf1d_out)) return 1;
    tmu_surface_1d_copy<<<1, (unsigned)data1d.size()>>>(surf1d_in, surf1d_out, (int)data1d.size());
    std::vector<float> surf1d_out_host(data1d.size());
    CHECK_CUDA(cudaMemcpy2DFromArray(surf1d_out_host.data(),
                                     data1d.size() * sizeof(float),
                                     surf1d_arr_out, 0, 0,
                                     data1d.size() * sizeof(float), 1,
                                     cudaMemcpyDeviceToHost));
    rc |= expect_affine("tmu_surface_1d_copy", surf1d_out_host, data1d, 3.0f);

    CHECK_CUDA(cudaMallocArray(&surf2d_arr_in, &channel, w2, h2, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMallocArray(&surf2d_arr_out, &channel, w2, h2, cudaArraySurfaceLoadStore));
    CHECK_CUDA(cudaMemcpy2DToArray(surf2d_arr_in, 0, 0, data2d.data(), (size_t)w2 * sizeof(float),
                                   (size_t)w2 * sizeof(float), h2, cudaMemcpyHostToDevice));
    if (make_surface(surf2d_arr_in, &surf2d_in)) return 1;
    if (make_surface(surf2d_arr_out, &surf2d_out)) return 1;
    tmu_surface_2d_copy<<<dim3(1, 1, 1), dim3(w2, h2, 1)>>>(surf2d_in, surf2d_out, w2, h2);
    std::vector<float> surf2d_out_host(data2d.size());
    CHECK_CUDA(cudaMemcpy2DFromArray(surf2d_out_host.data(), (size_t)w2 * sizeof(float), surf2d_arr_out, 0, 0,
                                     (size_t)w2 * sizeof(float), h2, cudaMemcpyDeviceToHost));
    rc |= expect_affine("tmu_surface_2d_copy", surf2d_out_host, data2d, 5.0f);

    tmu_surface_oob_zero<<<1, 1>>>(d_out, surf2d_in, w2, h2);
    CHECK_CUDA(cudaMemcpy(out_addr.data(), d_out, sizeof(float), cudaMemcpyDeviceToHost));
    if (!nearly_equal(out_addr[0], 0.0f)) {
        fprintf(stderr, "tmu_surface_oob_zero mismatch: got=%f expected=0\n", out_addr[0]);
        rc |= 2;
    } else {
        printf("tmu_surface_oob_zero: OK\n");
    }

    tmu_surface_oob_clamp<<<1, 1>>>(d_out, surf2d_in, w2, h2);
    CHECK_CUDA(cudaMemcpy(out_addr.data(), d_out, sizeof(float), cudaMemcpyDeviceToHost));
    if (!nearly_equal(out_addr[0], data2d.back())) {
        fprintf(stderr, "tmu_surface_oob_clamp mismatch: got=%f expected=%f\n", out_addr[0], data2d.back());
        rc |= 2;
    } else {
        printf("tmu_surface_oob_clamp: OK\n");
    }

    for (int m = 0; m < 4; ++m) {
        cudaDestroyTextureObject(addr_tex[m]);
        cudaFreeArray(addr_arr[m]);
    }
    cudaDestroySurfaceObject(surf2d_out);
    cudaDestroySurfaceObject(surf2d_in);
    cudaDestroySurfaceObject(surf1d_out);
    cudaDestroySurfaceObject(surf1d_in);
    cudaFreeArray(surf2d_arr_out);
    cudaFreeArray(surf2d_arr_in);
    cudaFreeArray(surf1d_arr_out);
    cudaFreeArray(surf1d_arr_in);
    cudaDestroyTextureObject(tex3d_linear);
    cudaDestroyTextureObject(tex3d_point);
    cudaDestroyTextureObject(tex2d_linear);
    cudaDestroyTextureObject(tex2d_point);
    cudaDestroyTextureObject(tex1d_linear);
    cudaDestroyTextureObject(tex1d_point);
    cudaFreeArray(arr3d_linear);
    cudaFreeArray(arr3d_point);
    cudaFreeArray(arr2d_linear);
    cudaFreeArray(arr2d_point);
    cudaFreeArray(arr1d_linear);
    cudaFreeArray(arr1d_point);
    cudaFree(d_coords2d);
    cudaFree(d_coords1d);
    cudaFree(d_out);
    return rc;
}

int main(int argc, char **argv) {
    std::string mode = argc > 1 ? argv[1] : "probe_tmu_behavior";
    if (mode == "probe_texture_surface") {
        return run_probe_texture_surface();
    }
    if (mode == "probe_tmu_behavior") {
        return run_probe_tmu_behavior();
    }
    fprintf(stderr, "unknown texture runner mode: %s\n", mode.c_str());
    return 2;
}
