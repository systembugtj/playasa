/*
 * Project-owned DXVA codec contracts.
 *
 * These structures isolate DXVA decoders from FFmpeg private structs.
 */

#pragma once

#include <dxva.h>

#define DXVA_MPEG2_MAX_SLICES 175
#define DXVA_H264_MAX_SLICES 16

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

/* RFC-0033: H.264 DXVA picture contract (parse + BuildPicParams metadata). */
typedef struct DxvaH264PictureContext {
	DXVA_PicParams_H264 picParams;
	DXVA_Qmatrix_H264 scalingMatrix;
	int fieldType;
	int sliceType;
	int framePOC;
	int outPOC;
	__int64 outRtStart;
	BOOL intraPicFlag;
} DxvaH264PictureContext;

/* RFC-0047 phase 4a: opaque H.264 DXVA session; AVCodecContext optional when modern parse bridge is available. */
typedef struct DxvaH264DxvaSession DxvaH264DxvaSession;

/* RFC-0033: VC-1 DXVA picture contract. */
typedef struct DxvaVc1PictureContext {
	DXVA_PictureParameters pictureParams;
	int fieldType;
	int sliceType;
	BOOL frameSkipped;
} DxvaVc1PictureContext;

/* RFC-0047 phase 4c-ii: opaque VC-1 DXVA session; AVCodecContext optional when modern parse bridge is available. */
typedef struct DxvaVc1DxvaSession DxvaVc1DxvaSession;

/* RFC-0047 phase 4c-ii: opaque MPEG-2 DXVA session; AVCodecContext optional when modern parse bridge is available. */
typedef struct DxvaMpeg2DxvaSession DxvaMpeg2DxvaSession;
