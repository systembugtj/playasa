/*
 * Project-owned DXVA codec contracts.
 *
 * These structures isolate DXVA decoders from FFmpeg private structs.
 */

#pragma once

#include <dxva.h>

#define DXVA_MPEG2_MAX_SLICES 175

typedef struct DxvaMpeg2PictureContext {
	DXVA_PictureParameters pictureParams;
	DXVA_QmatrixData qmatrixData;
	DXVA_SliceInfo sliceInfo[DXVA_MPEG2_MAX_SLICES];
	int sliceCount;
	int nextCodecIndex;
	int fieldType;
	int sliceType;
	int codedPictureNumber;
	BOOL alternateScan;
} DxvaMpeg2PictureContext;
