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

enum {
    PLAYASA_FFMPEG_MODERN_CODEC_MPEG4 = 0,
    PLAYASA_FFMPEG_MODERN_CODEC_FLV1 = 1,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6 = 2,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6F = 3,
    PLAYASA_FFMPEG_MODERN_CODEC_VP6A = 4,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV1 = 5,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV2 = 6,
    PLAYASA_FFMPEG_MODERN_CODEC_H264 = 7,
    PLAYASA_FFMPEG_MODERN_CODEC_MPEG2 = 8
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

typedef struct PlayasaFfmpegModernFrameInfo {
    int32_t width;
    int32_t height;
    int32_t pixel_format;
    int64_t pts;
    const uint8_t* data[4];
    int32_t linesize[4];
} PlayasaFfmpegModernFrameInfo;

PLAYASA_FFMPEG_MODERN_API uint32_t playasa_ffmpeg_modern_avcodec_version(void);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_codec_from_fourcc(uint32_t fourcc, uint32_t* codec);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_create(uint32_t codec, PlayasaFfmpegModernSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_open(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode_with_pts(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, int64_t pts, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_drain(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_flush(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API const char* playasa_ffmpeg_modern_last_error(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_destroy(PlayasaFfmpegModernSession session);

#ifdef __cplusplus
}
#endif
