/* RFC-0047 phase 3f: legacy MPEG-2 DXVA glue compartment (libavcodec_gcc). */
#define HAVE_AV_CONFIG_H
#include <windows.h>
#include <winnt.h>
#include <vfwmsgs.h>
#include "FfmpegContext.h"
#include "dsputil.h"
#include "avcodec.h"
#include "mpegvideo.h"

BOOL FFAvctxIsMpeg2Video(struct AVCodecContext* pAVCtx)
{
	return pAVCtx && pAVCtx->codec_id == CODEC_ID_MPEG2VIDEO;
}

/* FIXME: remove duplicate declaration with ffmpeg ?? */
typedef struct Mpeg1Context {
	MpegEncContext mpeg_enc_ctx;
	int mpeg_enc_ctx_allocated;
	int repeat_field;
	AVPanScan pan_scan;
	int slice_count;
	int swap_uv;
	int save_aspect_info;
	int save_width, save_height, save_progressive_seq;
	AVRational frame_rate_ext;
	int sync;
	DXVA_SliceInfo* pSliceInfo;
} Mpeg1Context;

static const byte kZzScan[16] =
{  0,  1,  4,  8,  5,  2,  3,  6,  9, 12, 13, 10,  7, 11, 14, 15
};

static const byte kZzScan8[64] =
{  0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
   12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
   35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
   58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};

static MpegEncContext* GetMpeg2EncContext(struct AVCodecContext* pAVCtx)
{
	Mpeg1Context* s1;

	if (!pAVCtx || pAVCtx->codec_id != CODEC_ID_MPEG2VIDEO) {
		return NULL;
	}

	s1 = (Mpeg1Context*)pAVCtx->priv_data;
	return (MpegEncContext*)&s1->mpeg_enc_ctx;
}

unsigned long FFGetMpeg2MBNumber(struct AVCodecContext* pAVCtx)
{
	MpegEncContext* s = GetMpeg2EncContext(pAVCtx);
	return (s != NULL) ? s->mb_num : 0;
}

int FFGetMpeg2CodedPicture(struct AVCodecContext* pAVCtx)
{
	MpegEncContext* s = GetMpeg2EncContext(pAVCtx);
	return (s != NULL) ? s->current_picture.coded_picture_number : 0;
}

BOOL FFGetMpeg2AlternateScan(struct AVCodecContext* pAVCtx)
{
	MpegEncContext* s = GetMpeg2EncContext(pAVCtx);
	return (s != NULL) ? s->alternate_scan : 0;
}

HRESULT FFMpeg2ReadPictureContext(DxvaMpeg2PictureContext* pContext, struct AVCodecContext* pAVCtx, struct AVFrame* pFrame, BYTE* pBuffer, UINT nSize)
{
	int i;
	int got_picture = 0;
	Mpeg1Context* s1 = (Mpeg1Context*)pAVCtx->priv_data;
	MpegEncContext* s = (MpegEncContext*)&s1->mpeg_enc_ctx;

	if (pBuffer) {
		s1->pSliceInfo = pContext->sliceInfo;
		avcodec_decode_video(pAVCtx, pFrame, &got_picture, pBuffer, nSize);
		pContext->sliceCount = s1->slice_count;
	}

	pContext->pictureParams.wPicWidthInMBminus1 = s->mb_width - 1;
	pContext->pictureParams.wPicHeightInMBminus1 = s->mb_height - 1;
	pContext->pictureParams.bMacroblockWidthMinus1 = 15;
	pContext->pictureParams.bMacroblockHeightMinus1 = 15;
	pContext->pictureParams.bBlockWidthMinus1 = 7;
	pContext->pictureParams.bBlockHeightMinus1 = 7;
	pContext->pictureParams.bBPPminus1 = 7;
	pContext->pictureParams.bPicStructure = s->picture_structure;
	pContext->pictureParams.bPicIntra = (s->current_picture.pict_type == FF_I_TYPE);
	pContext->pictureParams.bPicBackwardPrediction = (s->current_picture.pict_type == FF_B_TYPE);
	pContext->pictureParams.bBidirectionalAveragingMode = 0;
	pContext->pictureParams.bChromaFormat = 0x01;
	pContext->pictureParams.wBitstreamFcodes = (s->mpeg_f_code[0][0] << 12) | (s->mpeg_f_code[0][1] << 8) |
		(s->mpeg_f_code[1][0] << 4) | (s->mpeg_f_code[1][1]);
	pContext->pictureParams.wBitstreamPCEelements = (s->intra_dc_precision << 14) | (s->picture_structure << 12) |
		(s->top_field_first << 11) | (s->frame_pred_frame_dct << 10) |
		(s->concealment_motion_vectors << 9) | (s->q_scale_type << 8) |
		(s->intra_vlc_format << 7) | (s->alternate_scan << 6) |
		(s->repeat_first_field << 5) | (s->chroma_420_type << 4) |
		(s->progressive_frame << 3);

	pContext->qmatrixData.bNewQmatrix[0] = 1;
	pContext->qmatrixData.bNewQmatrix[1] = 1;
	pContext->qmatrixData.bNewQmatrix[2] = 1;
	pContext->qmatrixData.bNewQmatrix[3] = 1;
	for (i = 0; i < 64; i++) {
		pContext->qmatrixData.Qmatrix[0][i] = s->intra_matrix[kZzScan8[i]];
		pContext->qmatrixData.Qmatrix[1][i] = s->inter_matrix[kZzScan8[i]];
		pContext->qmatrixData.Qmatrix[2][i] = s->chroma_intra_matrix[kZzScan8[i]];
		pContext->qmatrixData.Qmatrix[3][i] = s->chroma_inter_matrix[kZzScan8[i]];
	}

	if (got_picture) {
		pContext->nextCodecIndex = pFrame->coded_picture_number;
	}
	pContext->fieldType = s->picture_structure;
	pContext->sliceType = s->current_picture.pict_type;
	pContext->codedPictureNumber = s->current_picture.coded_picture_number;
	pContext->alternateScan = s->alternate_scan;

	return S_OK;
}

HRESULT FFMpeg2DecodeFrame(DXVA_PictureParameters* pPicParams, DXVA_QmatrixData* pQMatrixData, DXVA_SliceInfo* pSliceInfo, int* nSliceCount,
	struct AVCodecContext* pAVCtx, struct AVFrame* pFrame, int* nNextCodecIndex, int* nFieldType, int* nSliceType, BYTE* pBuffer, UINT nSize)
{
	HRESULT hr;
	DxvaMpeg2PictureContext context;

	memset(&context, 0, sizeof(context));
	context.pictureParams = *pPicParams;
	context.qmatrixData = *pQMatrixData;
	memcpy(context.sliceInfo, pSliceInfo, sizeof(DXVA_SliceInfo) * (*nSliceCount));
	context.sliceCount = *nSliceCount;
	context.nextCodecIndex = *nNextCodecIndex;
	context.fieldType = *nFieldType;
	context.sliceType = *nSliceType;
	context.codedPictureNumber = FFGetMpeg2CodedPicture(pAVCtx);
	context.alternateScan = FFGetMpeg2AlternateScan(pAVCtx);

	hr = FFMpeg2ReadPictureContext(&context, pAVCtx, pFrame, pBuffer, nSize);
	if (FAILED(hr)) {
		return hr;
	}

	*pPicParams = context.pictureParams;
	*pQMatrixData = context.qmatrixData;
	memcpy(pSliceInfo, context.sliceInfo, sizeof(DXVA_SliceInfo) * context.sliceCount);
	*nSliceCount = context.sliceCount;
	*nNextCodecIndex = context.nextCodecIndex;
	*nFieldType = context.fieldType;
	*nSliceType = context.sliceType;

	return S_OK;
}
