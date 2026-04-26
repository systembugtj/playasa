#define PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS

#include "../../../../Thirdparty/pkg/ffmpeg_modern_bridge.h"
#include "ModernFfmpegDecodeAdapter.h"

extern "C" {
#include "libavcodec/avcodec.h"
}

namespace {

ModernFfmpeg::DecodeCodec ToAdapterCodec(uint32_t codec)
{
    switch (codec) {
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG4:
        return ModernFfmpeg::kDecodeCodecMpeg4;
    case PLAYASA_FFMPEG_MODERN_CODEC_FLV1:
        return ModernFfmpeg::kDecodeCodecFlv1;
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6:
        return ModernFfmpeg::kDecodeCodecVp6;
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV1:
        return ModernFfmpeg::kDecodeCodecWmv1;
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV2:
        return ModernFfmpeg::kDecodeCodecWmv2;
    default:
        return ModernFfmpeg::kDecodeCodecMpeg4;
    }
}

bool IsValidCodec(uint32_t codec)
{
    switch (codec) {
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG4:
    case PLAYASA_FFMPEG_MODERN_CODEC_FLV1:
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6:
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV1:
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV2:
        return true;
    default:
        return false;
    }
}

ModernFfmpeg::DecodeSession* ToSession(PlayasaFfmpegModernSession session)
{
    return static_cast<ModernFfmpeg::DecodeSession*>(session);
}

int ToBridgeStatus(ModernFfmpeg::DecodeStatus status)
{
    switch (status) {
    case ModernFfmpeg::kDecodeStatusFrameReady:
        return PLAYASA_FFMPEG_MODERN_STATUS_FRAME_READY;
    case ModernFfmpeg::kDecodeStatusNeedMoreInput:
        return PLAYASA_FFMPEG_MODERN_STATUS_NEED_MORE_INPUT;
    case ModernFfmpeg::kDecodeStatusEndOfStream:
        return PLAYASA_FFMPEG_MODERN_STATUS_END_OF_STREAM;
    case ModernFfmpeg::kDecodeStatusFailure:
    default:
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

void CopyFrameInfo(const ModernFfmpeg::DecodedFrameInfo& source, PlayasaFfmpegModernFrameInfo* target)
{
    if (!target) {
        return;
    }

    target->width = source.width;
    target->height = source.height;
    target->pixel_format = source.pixelFormat;
    target->pts = source.pts;
}

uint32_t ToBridgeCodec(ModernFfmpeg::DecodeCodec codec)
{
    switch (codec) {
    case ModernFfmpeg::kDecodeCodecMpeg4:
        return PLAYASA_FFMPEG_MODERN_CODEC_MPEG4;
    case ModernFfmpeg::kDecodeCodecFlv1:
        return PLAYASA_FFMPEG_MODERN_CODEC_FLV1;
    case ModernFfmpeg::kDecodeCodecVp6:
        return PLAYASA_FFMPEG_MODERN_CODEC_VP6;
    case ModernFfmpeg::kDecodeCodecWmv1:
        return PLAYASA_FFMPEG_MODERN_CODEC_WMV1;
    case ModernFfmpeg::kDecodeCodecWmv2:
        return PLAYASA_FFMPEG_MODERN_CODEC_WMV2;
    default:
        return PLAYASA_FFMPEG_MODERN_CODEC_MPEG4;
    }
}

} // namespace

extern "C" {

uint32_t playasa_ffmpeg_modern_avcodec_version(void)
{
    return avcodec_version();
}

int playasa_ffmpeg_modern_codec_from_fourcc(uint32_t fourcc, uint32_t* codec)
{
    if (!codec) {
        return 0;
    }

    ModernFfmpeg::DecodeCodec adapterCodec = ModernFfmpeg::kDecodeCodecMpeg4;
    if (!ModernFfmpeg::DecodeCodecFromFourcc(fourcc, &adapterCodec)) {
        return 0;
    }

    *codec = ToBridgeCodec(adapterCodec);
    return 1;
}

int playasa_ffmpeg_modern_create(uint32_t codec, PlayasaFfmpegModernSession* session)
{
    if (!session || !IsValidCodec(codec)) {
        return 0;
    }

    try {
        *session = new ModernFfmpeg::DecodeSession(ToAdapterCodec(codec));
        return *session ? 1 : 0;
    } catch (...) {
        *session = 0;
        return 0;
    }
}

int playasa_ffmpeg_modern_open(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return 0;
    }
    if (!extra_data && extra_data_size > 0) {
        return 0;
    }

    try {
        return decodeSession->OpenWithExtradata(extra_data, extra_data_size) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

int playasa_ffmpeg_modern_decode(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, PlayasaFfmpegModernFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->Decode(data, data_size, &adapterFrame));
        CopyFrameInfo(adapterFrame, frame_info);
        return status;
    } catch (...) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

int playasa_ffmpeg_modern_drain(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->Drain(&adapterFrame));
        CopyFrameInfo(adapterFrame, frame_info);
        return status;
    } catch (...) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

void playasa_ffmpeg_modern_flush(PlayasaFfmpegModernSession session)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (decodeSession) {
        decodeSession->Flush();
    }
}

const char* playasa_ffmpeg_modern_last_error(PlayasaFfmpegModernSession session)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    return decodeSession ? decodeSession->LastError() : "Invalid FFmpeg modern session";
}

void playasa_ffmpeg_modern_destroy(PlayasaFfmpegModernSession session)
{
    delete ToSession(session);
}

} // extern "C"
