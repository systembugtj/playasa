#pragma once

// RFC-0047 phase 4c-ii: modern-island MPEG-2 DXVA parse ABI (no legacy libavcodec_gcc).

#include "ffmpeg_modern_bridge.h"

#include <stddef.h>
#include <stdint.h>

#if defined(PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS)
#include "playasa_dxva_types.h"
#else
#include <dxva.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define PLAYASA_DXVA_MPEG2_MAX_SLICES 175

typedef struct PlayasaDxvaMpeg2ParseSession PlayasaDxvaMpeg2ParseSession;

typedef struct PlayasaDxvaMpeg2ParseOutput {
	DXVA_PictureParameters picture_params;
	DXVA_QmatrixData qmatrix_data;
	DXVA_SliceInfo slice_info[PLAYASA_DXVA_MPEG2_MAX_SLICES];
	int slice_count;
	int field_type;
	int slice_type;
	int coded_picture_number;
	int alternate_scan;
	int next_codec_index;
} PlayasaDxvaMpeg2ParseOutput;

PLAYASA_FFMPEG_MODERN_API int playasa_dxva_mpeg2_parse_create(PlayasaDxvaMpeg2ParseSession** session);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_mpeg2_parse_destroy(PlayasaDxvaMpeg2ParseSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_mpeg2_parse_open(
	PlayasaDxvaMpeg2ParseSession* session,
	const uint8_t* extra_data,
	size_t extra_data_size);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_mpeg2_parse_buffer(
	PlayasaDxvaMpeg2ParseSession* session,
	const uint8_t* data,
	size_t data_size,
	PlayasaDxvaMpeg2ParseOutput* output);

#ifdef __cplusplus
}
#endif
