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
    PLAYASA_FFMPEG_MODERN_CODEC_WMV1 = 3,
    PLAYASA_FFMPEG_MODERN_CODEC_WMV2 = 4
};

enum {
    PLAYASA_FFMPEG_MODERN_STATUS_FAILURE = -1,
    PLAYASA_FFMPEG_MODERN_STATUS_FRAME_READY = 1,
    PLAYASA_FFMPEG_MODERN_STATUS_NEED_MORE_INPUT = 2,
    PLAYASA_FFMPEG_MODERN_STATUS_END_OF_STREAM = 3
};

typedef struct PlayasaFfmpegModernFrameInfo {
    int32_t width;
    int32_t height;
    int32_t pixel_format;
    int64_t pts;
} PlayasaFfmpegModernFrameInfo;

PLAYASA_FFMPEG_MODERN_API uint32_t playasa_ffmpeg_modern_avcodec_version(void);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_codec_from_fourcc(uint32_t fourcc, uint32_t* codec);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_create(uint32_t codec, PlayasaFfmpegModernSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_open(PlayasaFfmpegModernSession session, const uint8_t* extra_data, size_t extra_data_size);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_decode(PlayasaFfmpegModernSession session, const uint8_t* data, size_t data_size, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API int playasa_ffmpeg_modern_drain(PlayasaFfmpegModernSession session, PlayasaFfmpegModernFrameInfo* frame_info);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_flush(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API const char* playasa_ffmpeg_modern_last_error(PlayasaFfmpegModernSession session);
PLAYASA_FFMPEG_MODERN_API void playasa_ffmpeg_modern_destroy(PlayasaFfmpegModernSession session);

#ifdef __cplusplus
}
#endif
