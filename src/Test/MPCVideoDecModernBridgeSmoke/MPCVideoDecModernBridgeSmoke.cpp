#include "../../Thirdparty/pkg/ffmpeg_modern_bridge.h"

#include <stdio.h>
#include <windows.h>

namespace {

const uint32_t kFourccXvid = 'X' | ('V' << 8) | ('I' << 16) | ('D' << 24);
const uint32_t kFourccWvc1 = 'W' | ('V' << 8) | ('C' << 16) | ('1' << 24);
const uint32_t kFourccWmv3 = 'W' | ('M' << 8) | ('V' << 16) | ('3' << 24);

bool CheckCodec(uint32_t fourcc, bool openSession)
{
    uint32_t codec = 0;
    if (!playasa_ffmpeg_modern_codec_from_fourcc(fourcc, &codec)) {
        fprintf(stderr, "fourcc 0x%08x was not mapped\n", fourcc);
        return false;
    }

    PlayasaFfmpegModernSession session = 0;
    if (!playasa_ffmpeg_modern_create(codec, &session) || !session) {
        fprintf(stderr, "failed to create bridge session for 0x%08x\n", fourcc);
        return false;
    }

    if (openSession) {
        if (!playasa_ffmpeg_modern_open(session, 0, 0)) {
            fprintf(stderr, "failed to open bridge session for 0x%08x: %s\n", fourcc, playasa_ffmpeg_modern_last_error(session));
            playasa_ffmpeg_modern_destroy(session);
            return false;
        }
    }

    playasa_ffmpeg_modern_destroy(session);
    return true;
}

const char* const kBridgeDllName = "playasa_ffmpeg_modern_bridge.dll";

using DxvaParseSession = void;

using DxvaParseCreateFn = int (*)(DxvaParseSession** session);
using DxvaParseDestroyFn = void (*)(DxvaParseSession* session);
using DxvaH264ParseOpenFn = int (*)(DxvaParseSession* session, const uint8_t* extra_data, size_t extra_data_size, int32_t nal_length_size);
using DxvaParseOpenFn = int (*)(DxvaParseSession* session, const uint8_t* extra_data, size_t extra_data_size);

struct DxvaParseApi {
    DxvaParseCreateFn create;
    DxvaParseDestroyFn destroy;
    DxvaH264ParseOpenFn h264Open;
    DxvaParseOpenFn open;
};

DxvaParseApi LoadDxvaParseApi(const char* createName, const char* destroyName, const char* openName, bool h264Open)
{
    DxvaParseApi api = {};
    HMODULE module = GetModuleHandleA(kBridgeDllName);
    if (!module) {
        fprintf(stderr, "bridge DLL is not loaded: %s\n", kBridgeDllName);
        return api;
    }

    api.create = reinterpret_cast<DxvaParseCreateFn>(GetProcAddress(module, createName));
    api.destroy = reinterpret_cast<DxvaParseDestroyFn>(GetProcAddress(module, destroyName));
    if (h264Open) {
        api.h264Open = reinterpret_cast<DxvaH264ParseOpenFn>(GetProcAddress(module, openName));
    } else {
        api.open = reinterpret_cast<DxvaParseOpenFn>(GetProcAddress(module, openName));
    }

    if (!api.create || !api.destroy || (!api.h264Open && !api.open)) {
        fprintf(stderr, "missing DXVA parse export(s) for %s/%s/%s\n", createName, destroyName, openName);
        api = {};
    }
    return api;
}

bool CheckDxvaParseLifecycle(const DxvaParseApi& api, const char* codecLabel, bool requireOpen, int32_t nalLengthSize)
{
    if (!api.create || !api.destroy) {
        fprintf(stderr, "%s DXVA parse API was not resolved\n", codecLabel);
        return false;
    }

    DxvaParseSession* session = 0;
    if (!api.create(&session) || !session) {
        fprintf(stderr, "failed to create %s DXVA parse session\n", codecLabel);
        return false;
    }

    if (requireOpen) {
        const int opened = api.h264Open
            ? api.h264Open(session, 0, 0, nalLengthSize)
            : api.open(session, 0, 0);
        if (!opened) {
            fprintf(stderr, "failed to open %s DXVA parse session\n", codecLabel);
            api.destroy(session);
            return false;
        }
    }

    api.destroy(session);
    return true;
}

// RFC-0047 phase 5: runtime smoke for DXVA parse ABI via dynamic exports (no dxva.h).
bool CheckDxvaParseExports()
{
    const DxvaParseApi h264Api = LoadDxvaParseApi(
        "playasa_dxva_h264_parse_create",
        "playasa_dxva_h264_parse_destroy",
        "playasa_dxva_h264_parse_open",
        true);
    const DxvaParseApi vc1Api = LoadDxvaParseApi(
        "playasa_dxva_vc1_parse_create",
        "playasa_dxva_vc1_parse_destroy",
        "playasa_dxva_vc1_parse_open",
        false);
    const DxvaParseApi mpeg2Api = LoadDxvaParseApi(
        "playasa_dxva_mpeg2_parse_create",
        "playasa_dxva_mpeg2_parse_destroy",
        "playasa_dxva_mpeg2_parse_open",
        false);

    if (!CheckDxvaParseLifecycle(h264Api, "H.264", true, 4)) {
        return false;
    }
    // VC-1 decode init requires container extradata; create/destroy proves bridge linkage.
    if (!CheckDxvaParseLifecycle(vc1Api, "VC-1", false, 0)) {
        return false;
    }
    if (!CheckDxvaParseLifecycle(mpeg2Api, "MPEG-2", true, 0)) {
        return false;
    }
    return true;
}

bool CheckAudioCodec(uint32_t codec, int sampleRate, int channels, int blockAlign)
{
    PlayasaFfmpegModernSession session = 0;
    if (!playasa_ffmpeg_modern_create(codec, &session) || !session) {
        fprintf(stderr, "failed to create audio bridge session for codec=%u\n", codec);
        return false;
    }

    PlayasaFfmpegModernAudioOpenParams params = {};
    params.sample_rate = sampleRate;
    params.channels = channels;
    params.bit_rate = 128000;
    params.bits_per_coded_sample = 16;
    params.block_align = blockAlign;
    params.extra_data = 0;
    params.extra_data_size = 0;

    if (!playasa_ffmpeg_modern_open_audio(session, &params)) {
        fprintf(stderr, "failed to open audio codec=%u: %s\n", codec, playasa_ffmpeg_modern_last_error(session));
        playasa_ffmpeg_modern_destroy(session);
        return false;
    }

    playasa_ffmpeg_modern_destroy(session);
    return true;
}

} // namespace

int main()
{
    const uint32_t version = playasa_ffmpeg_modern_avcodec_version();
    if (version == 0) {
        fprintf(stderr, "avcodec version is zero\n");
        return 1;
    }

    if (!CheckCodec(kFourccXvid, true)) {
        return 2;
    }
    if (!CheckCodec(kFourccWvc1, false)) {
        return 3;
    }
    if (!CheckCodec(kFourccWmv3, false)) {
        return 4;
    }

    // RFC-0045: remaining RealAudio codecs must open via audio ABI.
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_AAC, 44100, 2, 0)) {
        return 5;
    }
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_RA144, 8000, 1, 20)) {
        return 6;
    }
    // FFmpeg ra_288 requires block_align == 38.
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_RA288, 8000, 1, 38)) {
        return 7;
    }

    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_WMAV2, 44100, 2, 1024)) {
        return 8;
    }
    if (!CheckAudioCodec(PLAYASA_FFMPEG_MODERN_CODEC_AMR_NB, 8000, 1, 32)) {
        return 9;
    }

    // COOK requires RealMedia extradata; create-only proves decoder is linked.
    {
        PlayasaFfmpegModernSession session = 0;
        if (!playasa_ffmpeg_modern_create(PLAYASA_FFMPEG_MODERN_CODEC_COOK, &session) || !session) {
            fprintf(stderr, "failed to create COOK bridge session\n");
            return 10;
        }
        playasa_ffmpeg_modern_destroy(session);
    }

    if (!CheckDxvaParseExports()) {
        return 11;
    }

    printf("bridge smoke OK: avcodec=%u (dxva parse create/open verified)\n", version);
    return 0;
}
