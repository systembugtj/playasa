#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS)
#define PLAYASA_FFMPEG_MODERN_API __declspec(dllexport)
#else
#define PLAYASA_FFMPEG_MODERN_API __declspec(dllimport)
#endif

typedef void* PlayasaFfmpegModernSession;

#define PLAYASA_FFMPEG_MODERN_NO_PTS INT64_MIN

enum {
    PLAYASA_FFMPEG_MODERN_CODEC_MPEG4 = 0,
    PLAYASA_FFMPEG_MODERN_CODEC_FLV1 = 1,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6 = 2,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6F = 3,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6A = 4,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV1 = 5,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV2 = 6,
    PLAYASA_FFMPEG_MODERN_CODEC_H264 = 7,
    PLAYASA_FFMPEG_MODERN_CODEC_MPEG2 = 8,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV3 = 9,
    PLAYASA_FFMPEG_MODERN_CODEC_VC1 = 10,
    PLAYASA_FFMPEG_MODERN_CODEC_RV10 = 11,
    PLAYASA_FFMPEG_MODERN_CODEC_RV20 = 12,
    PLAYASA_FFMPEG_MODERN_CODEC_RV30 = 13,
    PLAYASA_FFMPEG_MODERN_CODEC_RV40 = 14,
    PLAYASA_FFMPEG_MODERN_CODEC_MPEG1 = 15,
    PLAYASA_FFMPEG_MODERN_CODEC_COOK = 16,
    PLAYASA_FFMPEG_MODERN_CODEC_SIPR = 17,
    PLAYASA_FFMPEG_MODERN_CODEC_ATRAC3 = 18,
    PLAYASA_FFMPEG_MODERN_CODEC_AAC = 19,
    PLAYASA_FFMPEG_MODERN_CODEC_RA144 = 20,
    PLAYASA_FFMPEG_MODERN_CODEC_RA288 = 21
};

enum {
    PLAYASA_FFMPEG_MODERN_STATUS_FAILURE = -1,
    PLAYASA_FFMPEG_MODERN_STATUS_FRAME_READY = 1,
    PLAYASA_FFMPEG_MODERN_STATUS_NEED_MORE_INPUT = 2,
    PLAYASA_FFMPEG_MODERN_STATUS_END_OF_STREAM = 3
};

enum {
    PLAYASA_FFMPEG_MODERN_PIXFMT_UNKNOWN = 0,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUV420P = 1,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ420P = 2,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUV422P = 3,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ422P = 4,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUV444P = 5,
    PLAYASA_FFMPEG_MODERN_PIXFMT_YUVJ444P = 6,
    PLAYASA_FFMPEG_MODERN_PIXFMT_RGB24 = 7,
    PLAYASA_FFMPEG_MODERN_PIXFMT_BGR24 = 8,
    PLAYASA_FFMPEG_MODERN_PIXFMT_RGB32 = 9,
    PLAYASA_FFMPEG_MODERN_PIXFMT_PAL8 = 10,
    PLAYASA_FFMPEG_MODERN_PIXFMT_GRAY8 = 11
};

enum {
    PLAYASA_FFMPEG_MODERN_SAMPLEFMT_UNKNOWN = 0,
    PLAYASA_FFMPEG_MODERN_SAMPLEFMT_S16 = 1,
    PLAYASA_FFMPEG_MODERN_SAMPLEFMT_S32 = 2,
    PLAYASA_FFMPEG_MODERN_SAMPLEFMT_FLT = 3,
    PLAYASA_FFMPEG_MODERN_SAMPLEFMT_FLTP = 4
};

typedef struct PlayasaFfmpegModernFrameInfo {
    int32_t width;
    int32_t height;
    int32_t pixel_format;
    int64_t pts;
    int64_t duration;
    const uint8_t* data[4];
    int32_t linesize[4];
} PlayasaFfmpegModernFrameInfo;

typedef struct PlayasaFfmpegModernAudioOpenParams {
    int32_t sample_rate;
    int32_t channels;
    int32_t bit_rate;
    int32_t bits_per_coded_sample;
    int32_t block_align;
    const uint8_t* extra_data;
    size_t extra_data_size;
} PlayasaFfmpegModernAudioOpenParams;

typedef struct PlayasaFfmpegModernAudioFrameInfo {
    int32_t sample_rate;
    int32_t channels;
    int32_t sample_format;
    int32_t nb_samples;
    int64_t pts;
    const uint8_t* data;
    int32_t data_size;
} PlayasaFfmpegModernAudioFrameInfo;

PLAYASA_FFMPEG_MODERN_API uint32_t playasa_ffmpeg_modern_avcodec_version(void);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_codec_from_fourcc(uint32_t fourcc, uint32_t* codec);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_create(uint32_t codec, PlayasaFfmpegModernSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_open(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_open_with_h264_nal_length_size(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size, int32_t h264_nal_length_size);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_open_audio(PlayasaFfmpegModernSession session, const PlayasaFfmpegModernAudioOpenParams* params);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode_with_pts(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode_with_timing(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, int64_t duration, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode_audio(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, PlayasaFfmpegModernAudioFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_receive_pending(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_receive_audio(PlayasaFfmpegModernSession session, PlayasaFfmpegModernAudioFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_drain(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_flush(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API const char* playasa_ffmpeg_modern_last_error(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_destroy(PlayasaFfmpegModernSession session);

#ifdef __cplusplus
}
#endif
