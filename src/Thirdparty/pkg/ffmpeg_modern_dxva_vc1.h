#pragma once

// RFC-0047 phase 4c-ii: modern-island VC-1 DXVA parse ABI (no legacy libavcodec_gcc).

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

typedef struct PlayasaDxvaVc1ParseSession PlayasaDxvaVc1ParseSession;

typedef struct PlayasaDxvaVc1ParseOutput {
	DXVA_PictureParameters picture_params;
	int field_type;
	int slice_type;
	int frame_skipped;
} PlayasaDxvaVc1ParseOutput;

PLAYASA_FFMPEG_MODERN_API int playasa_dxva_vc1_parse_create(PlayasaDxvaVc1ParseSession** session);
PLAYASA_FFMPEG_MODERN_API void playasa_dxva_vc1_parse_destroy(PlayasaDxvaVc1ParseSession* session);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_vc1_parse_open(
	PlayasaDxvaVc1ParseSession* session,
	const uint8_t* extra_data,
	size_t extra_data_size);
PLAYASA_FFMPEG_MODERN_API int playasa_dxva_vc1_parse_buffer(
	PlayasaDxvaVc1ParseSession* session,
	const uint8_t* data,
	size_t data_size,
	PlayasaDxvaVc1ParseOutput* output);

#ifdef __cplusplus
}
#endif
