#define PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS

#include "ffmpeg_modern_bridge.h"
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
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6F:
        return ModernFfmpeg::kDecodeCodecVp6f;
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6A:
        return ModernFfmpeg::kDecodeCodecVp6a;
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV1:
        return ModernFfmpeg::kDecodeCodecWmv1;
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV2:
        return ModernFfmpeg::kDecodeCodecWmv2;
    case PLAYASA_FFMPEG_MODERN_CODEC_H264:
        return ModernFfmpeg::kDecodeCodecH264;
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG2:
        return ModernFfmpeg::kDecodeCodecMpeg2;
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV3:
        return ModernFfmpeg::kDecodeCodecWmv3;
    case PLAYASA_FFMPEG_MODERN_CODEC_VC1:
        return ModernFfmpeg::kDecodeCodecVc1;
    case PLAYASA_FFMPEG_MODERN_CODEC_RV10:
        return ModernFfmpeg::kDecodeCodecRv10;
    case PLAYASA_FFMPEG_MODERN_CODEC_RV20:
        return ModernFfmpeg::kDecodeCodecRv20;
    case PLAYASA_FFMPEG_MODERN_CODEC_RV30:
        return ModernFfmpeg::kDecodeCodecRv30;
    case PLAYASA_FFMPEG_MODERN_CODEC_RV40:
        return ModernFfmpeg::kDecodeCodecRv40;
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG1:
        return ModernFfmpeg::kDecodeCodecMpeg1;
    case PLAYASA_FFMPEG_MODERN_CODEC_COOK:
        return ModernFfmpeg::kDecodeCodecCook;
    case PLAYASA_FFMPEG_MODERN_CODEC_SIPR:
        return ModernFfmpeg::kDecodeCodecSipr;
    case PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3:
        return ModernFfmpeg::kDecodeCodecAtrac3;
    case PLAYASA_FFMPEG_MODERN_CODEC_AAC:
        return ModernFfmpeg::kDecodeCodecAac;
    case PLAYASA_FFMPEG_MODERN_CODEC_RA144:
        return ModernFfmpeg::kDecodeCodecRa144;
    case PLAYASA_FFMPEG_MODERN_CODEC_RA288:
        return ModernFfmpeg::kDecodeCodecRa288;
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
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6F:
    case PLAYASA_FFMPEG_MODERN_CODEC_VP6A:
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV1:
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV2:
    case PLAYASA_FFMPEG_MODERN_CODEC_H264:
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG2:
    case PLAYASA_FFMPEG_MODERN_CODEC_WMV3:
    case PLAYASA_FFMPEG_MODERN_CODEC_VC1:
    case PLAYASA_FFMPEG_MODERN_CODEC_RV10:
    case PLAYASA_FFMPEG_MODERN_CODEC_RV20:
    case PLAYASA_FFMPEG_MODERN_CODEC_RV30:
    case PLAYASA_FFMPEG_MODERN_CODEC_RV40:
    case PLAYASA_FFMPEG_MODERN_CODEC_MPEG1:
    case PLAYASA_FFMPEG_MODERN_CODEC_COOK:
    case PLAYASA_FFMPEG_MODERN_CODEC_SIPR:
    case PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3:
    case PLAYASA_FFMPEG_MODERN_CODEC_AAC:
    case PLAYASA_FFMPEG_MODERN_CODEC_RA144:
    case PLAYASA_FFMPEG_MODERN_CODEC_RA288:
        return true;
    default:
        return false;
    }
}

ModernFfmpeg::DecodeSession* ToSession(PlayasaFfmpegModernSession session)
{
    return static_cast<ModernFfmpeg::DecodeSession*>(session);
}

int ToBridgePixelFormat(int pixelFormat)
{
    switch (pixelFormat) {
    case AV_PIX_FMT_YUV420P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUV420P;
    case AV_PIX_FMT_YUVJ420P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ420P;
    case AV_PIX_FMT_YUV422P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUV422P;
    case AV_PIX_FMT_YUVJ422P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ422P;
    case AV_PIX_FMT_YUV444P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUV444P;
    case AV_PIX_FMT_YUVJ444P:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ444P;
    case AV_PIX_FMT_RGB24:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_RGB24;
    case AV_PIX_FMT_BGR24:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_BGR24;
    case AV_PIX_FMT_RGB32:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_RGB32;
    case AV_PIX_FMT_PAL8:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_PAL8;
    case AV_PIX_FMT_GRAY8:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_GRAY8;
    default:
        return PLAYASA_FFMPEG_MODERN_PIXFMT_UNKNOWN;
    }
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
    target->pixel_format = ToBridgePixelFormat(source.pixelFormat);
    target->pts = source.pts;
    target->duration = source.duration;
    for (int i = 0; i < 4; ++i) {
        target->data[i] = source.data[i];
        target->linesize[i] = source.linesize[i];
    }
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
    case ModernFfmpeg::kDecodeCodecVp6f:
        return PLAYASA_FFMPEG_MODERN_CODEC_VP6F;
    case ModernFfmpeg::kDecodeCodecVp6a:
        return PLAYASA_FFMPEG_MODERN_CODEC_VP6A;
    case ModernFfmpeg::kDecodeCodecWmv1:
        return PLAYASA_FFMPEG_MODERN_CODEC_WMV1;
    case ModernFfmpeg::kDecodeCodecWmv2:
        return PLAYASA_FFMPEG_MODERN_CODEC_WMV2;
    case ModernFfmpeg::kDecodeCodecH264:
        return PLAYASA_FFMPEG_MODERN_CODEC_H264;
    case ModernFfmpeg::kDecodeCodecMpeg2:
        return PLAYASA_FFMPEG_MODERN_CODEC_MPEG2;
    case ModernFfmpeg::kDecodeCodecWmv3:
        return PLAYASA_FFMPEG_MODERN_CODEC_WMV3;
    case ModernFfmpeg::kDecodeCodecVc1:
        return PLAYASA_FFMPEG_MODERN_CODEC_VC1;
    case ModernFfmpeg::kDecodeCodecRv10:
        return PLAYASA_FFMPEG_MODERN_CODEC_RV10;
    case ModernFfmpeg::kDecodeCodecRv20:
        return PLAYASA_FFMPEG_MODERN_CODEC_RV20;
    case ModernFfmpeg::kDecodeCodecRv30:
        return PLAYASA_FFMPEG_MODERN_CODEC_RV30;
    case ModernFfmpeg::kDecodeCodecRv40:
        return PLAYASA_FFMPEG_MODERN_CODEC_RV40;
    case ModernFfmpeg::kDecodeCodecMpeg1:
        return PLAYASA_FFMPEG_MODERN_CODEC_MPEG1;
    case ModernFfmpeg::kDecodeCodecCook:
        return PLAYASA_FFMPEG_MODERN_CODEC_COOK;
    case ModernFfmpeg::kDecodeCodecSipr:
        return PLAYASA_FFMPEG_MODERN_CODEC_SIPR;
    case ModernFfmpeg::kDecodeCodecAtrac3:
        return PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3;
    case ModernFfmpeg::kDecodeCodecAac:
        return PLAYASA_FFMPEG_MODERN_CODEC_AAC;
    case ModernFfmpeg::kDecodeCodecRa144:
        return PLAYASA_FFMPEG_MODERN_CODEC_RA144;
    case ModernFfmpeg::kDecodeCodecRa288:
        return PLAYASA_FFMPEG_MODERN_CODEC_RA288;
    default:
        return PLAYASA_FFMPEG_MODERN_CODEC_MPEG4;
    }
}

int ToBridgeSampleFormat(int sampleFormat)
{
    switch (sampleFormat) {
    case ModernFfmpeg::kSampleFormatS16:
        return PLAYASA_FFMPEG_MODERN_SAMPLEFMT_S16;
    case ModernFfmpeg::kSampleFormatS32:
        return PLAYASA_FFMPEG_MODERN_SAMPLEFMT_S32;
    case ModernFfmpeg::kSampleFormatFlt:
        return PLAYASA_FFMPEG_MODERN_SAMPLEFMT_FLT;
    case ModernFfmpeg::kSampleFormatFltp:
        return PLAYASA_FFMPEG_MODERN_SAMPLEFMT_FLTP;
    default:
        return PLAYASA_FFMPEG_MODERN_SAMPLEFMT_UNKNOWN;
    }
}

void CopyAudioFrameInfo(const ModernFfmpeg::DecodedAudioFrameInfo& source, PlayasaFfmpegModernAudioFrameInfo* target)
{
    if (!target) {
        return;
    }

    target->sample_rate = source.sampleRate;
    target->channels = source.channels;
    target->sample_format = ToBridgeSampleFormat(source.sampleFormat);
    target->nb_samples = source.nbSamples;
    target->pts = source.pts;
    target->data = source.data;
    target->data_size = source.dataSize;
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

int playasa_ffmpeg_modern_open_with_h264_nal_length_size(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size, int32_t h264_nal_length_size)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return 0;
    }
    if (!extra_data && extra_data_size > 0) {
        return 0;
    }

    try {
        return decodeSession->OpenWithH264NalLengthSize(extra_data, extra_data_size, h264_nal_length_size) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

int playasa_ffmpeg_modern_open(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size)
{
    return playasa_ffmpeg_modern_open_with_h264_nal_length_size(session, extra_data, extra_data_size, 0);
}

int playasa_ffmpeg_modern_open_audio(PlayasaFfmpegModernSession session, const PlayasaFfmpegModernAudioOpenParams* params)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession || !params) {
        return 0;
    }
    if (!params->extra_data && params->extra_data_size > 0) {
        return 0;
    }

    ModernFfmpeg::AudioOpenParams adapterParams = {};
    adapterParams.sampleRate = params->sample_rate;
    adapterParams.channels = params->channels;
    adapterParams.bitRate = params->bit_rate;
    adapterParams.bitsPerCodedSample = params->bits_per_coded_sample;
    adapterParams.blockAlign = params->block_align;
    adapterParams.extraData = params->extra_data;
    adapterParams.extraDataSize = params->extra_data_size;

    try {
        return decodeSession->OpenWithAudioParams(adapterParams) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

int playasa_ffmpeg_modern_decode(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, PlayasaFfmpegModernFrameInfo* frame_info)
{
    return playasa_ffmpeg_modern_decode_with_pts(session, data, data_size, PLAYASA_FFMPEG_MODERN_NO_PTS, frame_info);
}

int playasa_ffmpeg_modern_decode_with_pts(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, PlayasaFfmpegModernFrameInfo* frame_info)
{
    return playasa_ffmpeg_modern_decode_with_timing(session, data, data_size, pts, PLAYASA_FFMPEG_MODERN_NO_PTS, frame_info);
}

int playasa_ffmpeg_modern_decode_with_timing(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->DecodeWithTiming(data, data_size, pts, duration, &adapterFrame));
        CopyFrameInfo(adapterFrame, frame_info);
        return status;
    } catch (...) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

int playasa_ffmpeg_modern_receive_pending(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->ReceivePending(&adapterFrame));
        CopyFrameInfo(adapterFrame, frame_info);
        return status;
    } catch (...) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

int playasa_ffmpeg_modern_decode_audio(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, PlayasaFfmpegModernAudioFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedAudioFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->DecodeAudio(data, data_size, pts, &adapterFrame));
        CopyAudioFrameInfo(adapterFrame, frame_info);
        return status;
    } catch (...) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }
}

int playasa_ffmpeg_modern_receive_audio(PlayasaFfmpegModernSession session, PlayasaFfmpegModernAudioFrameInfo* frame_info)
{
    ModernFfmpeg::DecodeSession* decodeSession = ToSession(session);
    if (!decodeSession) {
        return PLAYASA_FFMPEG_MODERN_STATUS_FAILURE;
    }

    try {
        ModernFfmpeg::DecodedAudioFrameInfo adapterFrame = {};
        const int status = ToBridgeStatus(decodeSession->ReceiveAudio(&adapterFrame));
        CopyAudioFrameInfo(adapterFrame, frame_info);
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
