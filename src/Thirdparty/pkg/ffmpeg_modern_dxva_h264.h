#pragma once

// RFC-0047 phase 3b: modern-island H.264 DXVA parse ABI (no legacy libavcodec_gcc).

#include "ffmpeg_modern_bridge.h"

#include <stddef.h>
#include <stdint.h>

#include <dxva.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PlayasaDxvaH264ParseSession PlayasaDxvaH264ParseSession;

typedef struct PlayasaDxvaH264ParseOutput {
	int frame_poc;
	int out_poc;
	int64_t out_rt_start;
	int field_type;
	int slice_type;
	DXVA_PicParams_H264 pic_params;
	DXVA_Qmatrix_H264 scaling_matrix;
} PlayasaDxvaH264ParseOutput;

PLAYASA_FFMPEG_MODERN_API int playasa_dxva_h264_parse_create(PlayasaDxvaH264ParseSession** session);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_h264_parse_destroy(PlayasaDxvaH264ParseSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_h264_parse_open(
	PlayasaDxvaH264ParseSession* session,
	const uint8_t* extra_data,
	size_t extra_data_size,
	int32_t nal_length_size);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_h264_parse_buffer(
	PlayasaDxvaH264ParseSession* session,
	const uint8_t* data,
	size_t data_size,
	PlayasaDxvaH264ParseOutput* output);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_h264_parse_fill_picture_context(
	PlayasaDxvaH264ParseSession* session,
	int32_t pci_vendor,
	PlayasaDxvaH264ParseOutput* output);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_h264_parse_set_surface_index(PlayasaDxvaH264ParseSession* session, int surface_index);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_h264_parse_update_ref_frames(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* pic_params);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_h264_parse_is_ref_in_use(PlayasaDxvaH264ParseSession* session, int surface_index);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_h264_parse_update_slice_long(
	PlayasaDxvaH264ParseSession* session,
	DXVA_PicParams_H264* pic_params,
	DXVA_Slice_H264_Long* slice);

#ifdef __cplusplus
}
#endif
