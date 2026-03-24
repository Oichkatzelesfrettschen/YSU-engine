#include <cuda.h>

#include <nvidia-sdk/cuviddec.h>
#include <nvidia-sdk/nvEncodeAPI.h>

#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const char *nvenc_status_name(NVENCSTATUS err) {
    switch (err) {
        case NV_ENC_SUCCESS: return "NV_ENC_SUCCESS";
        case NV_ENC_ERR_NO_ENCODE_DEVICE: return "NV_ENC_ERR_NO_ENCODE_DEVICE";
        case NV_ENC_ERR_UNSUPPORTED_DEVICE: return "NV_ENC_ERR_UNSUPPORTED_DEVICE";
        case NV_ENC_ERR_INVALID_ENCODERDEVICE: return "NV_ENC_ERR_INVALID_ENCODERDEVICE";
        case NV_ENC_ERR_INVALID_DEVICE: return "NV_ENC_ERR_INVALID_DEVICE";
        case NV_ENC_ERR_DEVICE_NOT_EXIST: return "NV_ENC_ERR_DEVICE_NOT_EXIST";
        case NV_ENC_ERR_INVALID_PTR: return "NV_ENC_ERR_INVALID_PTR";
        case NV_ENC_ERR_INVALID_EVENT: return "NV_ENC_ERR_INVALID_EVENT";
        case NV_ENC_ERR_INVALID_PARAM: return "NV_ENC_ERR_INVALID_PARAM";
        case NV_ENC_ERR_INVALID_CALL: return "NV_ENC_ERR_INVALID_CALL";
        case NV_ENC_ERR_OUT_OF_MEMORY: return "NV_ENC_ERR_OUT_OF_MEMORY";
        case NV_ENC_ERR_ENCODER_NOT_INITIALIZED: return "NV_ENC_ERR_ENCODER_NOT_INITIALIZED";
        case NV_ENC_ERR_UNSUPPORTED_PARAM: return "NV_ENC_ERR_UNSUPPORTED_PARAM";
        case NV_ENC_ERR_LOCK_BUSY: return "NV_ENC_ERR_LOCK_BUSY";
        case NV_ENC_ERR_NOT_ENOUGH_BUFFER: return "NV_ENC_ERR_NOT_ENOUGH_BUFFER";
        case NV_ENC_ERR_INVALID_VERSION: return "NV_ENC_ERR_INVALID_VERSION";
        case NV_ENC_ERR_MAP_FAILED: return "NV_ENC_ERR_MAP_FAILED";
        case NV_ENC_ERR_NEED_MORE_INPUT: return "NV_ENC_ERR_NEED_MORE_INPUT";
        case NV_ENC_ERR_ENCODER_BUSY: return "NV_ENC_ERR_ENCODER_BUSY";
        case NV_ENC_ERR_EVENT_NOT_REGISTERD: return "NV_ENC_ERR_EVENT_NOT_REGISTERD";
        case NV_ENC_ERR_GENERIC: return "NV_ENC_ERR_GENERIC";
        case NV_ENC_ERR_INCOMPATIBLE_CLIENT_KEY: return "NV_ENC_ERR_INCOMPATIBLE_CLIENT_KEY";
        case NV_ENC_ERR_UNIMPLEMENTED: return "NV_ENC_ERR_UNIMPLEMENTED";
        case NV_ENC_ERR_RESOURCE_REGISTER_FAILED: return "NV_ENC_ERR_RESOURCE_REGISTER_FAILED";
        case NV_ENC_ERR_RESOURCE_NOT_REGISTERED: return "NV_ENC_ERR_RESOURCE_NOT_REGISTERED";
        case NV_ENC_ERR_RESOURCE_NOT_MAPPED: return "NV_ENC_ERR_RESOURCE_NOT_MAPPED";
        case NV_ENC_ERR_NEED_MORE_OUTPUT: return "NV_ENC_ERR_NEED_MORE_OUTPUT";
        default: return "NV_ENC_STATUS_UNKNOWN";
    }
}

static uint32_t align_up_u32(uint32_t value, uint32_t alignment) {
    return ((value + alignment - 1u) / alignment) * alignment;
}

static int check_drv(CUresult err, const char *file, int line) {
    if (err != CUDA_SUCCESS) {
        const char *name = "CUDA_ERROR_UNKNOWN";
        const char *msg = "";
        cuGetErrorName(err, &name);
        cuGetErrorString(err, &msg);
        fprintf(stderr, "CUDA driver error: %s (%d) %s at %s:%d\n",
                name, (int)err, msg ? msg : "", file, line);
        return 1;
    }
    return 0;
}

static int check_enc(NVENCSTATUS err, const char *file, int line) {
    if (err != NV_ENC_SUCCESS) {
        fprintf(stderr, "NVENC error: %s (%d) at %s:%d\n",
                nvenc_status_name(err), (int)err, file, line);
        return 1;
    }
    return 0;
}

#define CHECK_DRV(expr) do { if (check_drv((expr), __FILE__, __LINE__)) return 1; } while (0)
#define CHECK_ENC(expr) do { if (check_enc((expr), __FILE__, __LINE__)) return 1; } while (0)

int main(void) {
    CHECK_DRV(cuInit(0));
    CUdevice dev = 0;
    CHECK_DRV(cuDeviceGet(&dev, 0));
    CUcontext ctx = nullptr;
    CHECK_DRV(cuCtxCreate(&ctx, nullptr, 0, dev));

    CUVIDDECODECAPS decode_caps = {};
    decode_caps.eCodecType = cudaVideoCodec_H264;
    decode_caps.eChromaFormat = cudaVideoChromaFormat_420;
    decode_caps.nBitDepthMinus8 = 0;
    CHECK_DRV(cuvidGetDecoderCaps(&decode_caps));
    printf("nvdec_h264_supported=%u max=%ux%u output_mask=0x%x\n",
           decode_caps.bIsSupported,
           decode_caps.nMaxWidth,
           decode_caps.nMaxHeight,
           decode_caps.nOutputFormatMask);

    if (!decode_caps.bIsSupported) {
        fprintf(stderr, "NVDEC H.264 not supported on this GPU\n");
        return 2;
    }

    CUvideodecoder decoder = nullptr;
    CUVIDDECODECREATEINFO create_info = {};
    create_info.CodecType = cudaVideoCodec_H264;
    create_info.ChromaFormat = cudaVideoChromaFormat_420;
    create_info.OutputFormat = cudaVideoSurfaceFormat_NV12;
    create_info.bitDepthMinus8 = 0;
    create_info.DeinterlaceMode = cudaVideoDeinterlaceMode_Weave;
    create_info.ulWidth = 64;
    create_info.ulHeight = 64;
    create_info.ulNumDecodeSurfaces = 2;
    create_info.ulNumOutputSurfaces = 2;
    create_info.ulTargetWidth = 64;
    create_info.ulTargetHeight = 64;
    create_info.ulCreationFlags = cudaVideoCreate_Default;
    CHECK_DRV(cuvidCreateDecoder(&decoder, &create_info));
    CHECK_DRV(cuvidDestroyDecoder(decoder));

    NV_ENCODE_API_FUNCTION_LIST enc = {};
    enc.version = NV_ENCODE_API_FUNCTION_LIST_VER;
    CHECK_ENC(NvEncodeAPICreateInstance(&enc));

    void *encoder = nullptr;
    NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS open = {};
    open.version = NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS_VER;
    open.deviceType = NV_ENC_DEVICE_TYPE_CUDA;
    open.device = ctx;
    open.apiVersion = NVENCAPI_VERSION;
    CHECK_ENC(enc.nvEncOpenEncodeSessionEx(&open, &encoder));

    uint32_t guid_count = 0;
    CHECK_ENC(enc.nvEncGetEncodeGUIDCount(encoder, &guid_count));
    GUID guid_list[16];
    uint32_t guid_out = 0;
    CHECK_ENC(enc.nvEncGetEncodeGUIDs(encoder, guid_list, 16, &guid_out));
    printf("nvenc_guid_count=%u listed=%u\n", guid_count, guid_out);

    uint32_t preset_count = 0;
    CHECK_ENC(enc.nvEncGetEncodePresetCount(encoder, NV_ENC_CODEC_H264_GUID, &preset_count));
    GUID preset_guids[16];
    uint32_t preset_out = 0;
    CHECK_ENC(enc.nvEncGetEncodePresetGUIDs(encoder, NV_ENC_CODEC_H264_GUID, preset_guids, 16, &preset_out));
    printf("nvenc_h264_preset_count=%u listed=%u\n", preset_count, preset_out);

    uint32_t input_fmt_count = 0;
    CHECK_ENC(enc.nvEncGetInputFormatCount(encoder, NV_ENC_CODEC_H264_GUID, &input_fmt_count));
    NV_ENC_BUFFER_FORMAT input_formats[16];
    uint32_t input_fmt_out = 0;
    CHECK_ENC(enc.nvEncGetInputFormats(encoder, NV_ENC_CODEC_H264_GUID, input_formats, 16, &input_fmt_out));
    printf("nvenc_h264_input_formats=");
    for (uint32_t i = 0; i < input_fmt_out; ++i) {
        printf("%s%u", i ? "," : "", (unsigned)input_formats[i]);
    }
    printf("\n");

    auto query_cap = [&](NV_ENC_CAPS caps_to_query) -> int {
        NV_ENC_CAPS_PARAM caps = {};
        caps.version = NV_ENC_CAPS_PARAM_VER;
        caps.capsToQuery = caps_to_query;
        int value = 0;
        CHECK_ENC(enc.nvEncGetEncodeCaps(encoder, NV_ENC_CODEC_H264_GUID, &caps, &value));
        return value;
    };
    const uint32_t enc_width_min = (uint32_t)query_cap(NV_ENC_CAPS_WIDTH_MIN);
    const uint32_t enc_height_min = (uint32_t)query_cap(NV_ENC_CAPS_HEIGHT_MIN);
    const uint32_t enc_width = align_up_u32(enc_width_min > 128u ? enc_width_min : 128u, 16u);
    const uint32_t enc_height = align_up_u32(enc_height_min > 128u ? enc_height_min : 128u, 16u);
    printf("nvenc_h264_min_size=%ux%u using=%ux%u\n",
           enc_width_min, enc_height_min, enc_width, enc_height);

    const GUID chosen_preset = preset_out ? preset_guids[0] : NV_ENC_PRESET_P3_GUID;

    NV_ENC_PRESET_CONFIG preset = {};
    preset.version = NV_ENC_PRESET_CONFIG_VER;
    preset.presetCfg.version = NV_ENC_CONFIG_VER;
    CHECK_ENC(enc.nvEncGetEncodePresetConfigEx(
        encoder,
        NV_ENC_CODEC_H264_GUID,
        chosen_preset,
        NV_ENC_TUNING_INFO_LOW_LATENCY,
        &preset));

    NV_ENC_CONFIG config = preset.presetCfg;
    config.version = NV_ENC_CONFIG_VER;
    auto make_init = [&](GUID preset_guid, NV_ENC_TUNING_INFO tuning, NV_ENC_CONFIG *cfg) {
        NV_ENC_INITIALIZE_PARAMS init = {};
        init.version = NV_ENC_INITIALIZE_PARAMS_VER;
        init.encodeGUID = NV_ENC_CODEC_H264_GUID;
        init.presetGUID = preset_guid;
        init.encodeWidth = enc_width;
        init.encodeHeight = enc_height;
        init.darWidth = enc_width;
        init.darHeight = enc_height;
        init.frameRateNum = 30;
        init.frameRateDen = 1;
        init.enableEncodeAsync = 0;
        init.enablePTD = 1;
        init.maxEncodeWidth = enc_width;
        init.maxEncodeHeight = enc_height;
        init.tuningInfo = tuning;
        init.encodeConfig = cfg;
        return init;
    };

    NVENCSTATUS init_status = NV_ENC_SUCCESS;
    NV_ENC_INITIALIZE_PARAMS init = make_init(chosen_preset, NV_ENC_TUNING_INFO_UNDEFINED, nullptr);
    init_status = enc.nvEncInitializeEncoder(encoder, &init);
    printf("nvenc_init_attempt=minimal status=%s (%d)\n", nvenc_status_name(init_status), (int)init_status);
    if (init_status != NV_ENC_SUCCESS) {
        init = make_init(chosen_preset, NV_ENC_TUNING_INFO_LOW_LATENCY, &config);
        init_status = enc.nvEncInitializeEncoder(encoder, &init);
        printf("nvenc_init_attempt=preset_cfg status=%s (%d)\n", nvenc_status_name(init_status), (int)init_status);
    }
    if (init_status != NV_ENC_SUCCESS && preset_out && memcmp(&chosen_preset, &NV_ENC_PRESET_P3_GUID, sizeof(GUID)) != 0) {
        init = make_init(NV_ENC_PRESET_P3_GUID, NV_ENC_TUNING_INFO_LOW_LATENCY, &config);
        init_status = enc.nvEncInitializeEncoder(encoder, &init);
        printf("nvenc_init_attempt=p3_fallback status=%s (%d)\n", nvenc_status_name(init_status), (int)init_status);
    }
    if (init_status != NV_ENC_SUCCESS) {
        printf("nvenc_session_initialized=0\n");
        enc.nvEncDestroyEncoder(encoder);
        cuCtxDestroy(ctx);
        return 0;
    }

    CUdeviceptr d_nv12 = 0;
    const size_t pitch = enc_width;
    const size_t frame_bytes = pitch * enc_height * 3 / 2;
    CHECK_DRV(cuMemAlloc(&d_nv12, frame_bytes));
    CHECK_DRV(cuMemsetD8(d_nv12, 0x10, frame_bytes));

    NV_ENC_REGISTER_RESOURCE reg = {};
    reg.version = NV_ENC_REGISTER_RESOURCE_VER;
    reg.resourceType = NV_ENC_INPUT_RESOURCE_TYPE_CUDADEVICEPTR;
    reg.width = enc_width;
    reg.height = enc_height;
    reg.pitch = (uint32_t)pitch;
    reg.resourceToRegister = reinterpret_cast<void *>(d_nv12);
    reg.bufferFormat = NV_ENC_BUFFER_FORMAT_NV12;
    reg.bufferUsage = NV_ENC_INPUT_IMAGE;
    CHECK_ENC(enc.nvEncRegisterResource(encoder, &reg));

    NV_ENC_MAP_INPUT_RESOURCE mapped = {};
    mapped.version = NV_ENC_MAP_INPUT_RESOURCE_VER;
    mapped.registeredResource = reg.registeredResource;
    CHECK_ENC(enc.nvEncMapInputResource(encoder, &mapped));

    NV_ENC_CREATE_BITSTREAM_BUFFER bitstream = {};
    bitstream.version = NV_ENC_CREATE_BITSTREAM_BUFFER_VER;
    CHECK_ENC(enc.nvEncCreateBitstreamBuffer(encoder, &bitstream));

    printf("nvenc_session_initialized=1 mapped_fmt=%u\n", (unsigned)mapped.mappedBufferFmt);

    enc.nvEncDestroyBitstreamBuffer(encoder, bitstream.bitstreamBuffer);
    enc.nvEncUnmapInputResource(encoder, mapped.mappedResource);
    enc.nvEncUnregisterResource(encoder, reg.registeredResource);
    enc.nvEncDestroyEncoder(encoder);
    cuMemFree(d_nv12);
    cuCtxDestroy(ctx);
    return 0;
}
