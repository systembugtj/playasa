/* RFC-0047 phase 3e: legacy VC-1 DXVA glue compartment (libavcodec_gcc). */
#define HAVE_AV_CONFIG_H
#include <windows.h>
#include <winnt.h>
#include <vfwmsgs.h>
#include "FfmpegContext.h"
#include "dsputil.h"
#include "avcodec.h"
#include "mpegvideo.h"
#include "vc1.h"

BOOL FFAvctxIsVc1(struct AVCodecContext* pAVCtx)
{
	return pAVCtx && pAVCtx->codec_id == CODEC_ID_VC1;
}

int av_vc1_decode_frame(struct AVCodecContext* avctx, uint8_t* buf, int buf_size);

HRESULT FFVC1UpdatePictureParam(DXVA_PictureParameters* pPicParams, struct AVCodecContext* pAVCtx, int* nFieldType, int* nSliceType, BYTE* pBuffer, UINT nSize)
{
	VC1Context* vc1 = (VC1Context*)pAVCtx->priv_data;

	if (pBuffer) {
		av_vc1_decode_frame(pAVCtx, pBuffer, nSize);
	}

	/* WARNING: vc1->interlace is not reliable (always set for progressive video on HD-DVD material). */
	if (vc1->fcm == 0) {
		*nFieldType = PICT_FRAME;
	} else {
		*nFieldType = (vc1->tff ? PICT_TOP_FIELD : PICT_BOTTOM_FIELD);
	}

	pPicParams->bPicIntra = (vc1->s.pict_type == FF_I_TYPE);
	pPicParams->bPicBackwardPrediction = (vc1->s.pict_type == FF_B_TYPE);

	pPicParams->bBidirectionalAveragingMode = (pPicParams->bBidirectionalAveragingMode & 0xE0) |
		((vc1->lumshift != 0 || vc1->lumscale != 32) ? 0x10 : 0) |
		((vc1->profile == PROFILE_ADVANCED) << 3);

	pPicParams->bPicSpatialResid8 = (vc1->panscanflag << 7) | (vc1->refdist_flag << 6) |
		(vc1->s.loop_filter << 5) | (vc1->fastuvmc << 4) |
		(vc1->extended_mv << 3) | (vc1->dquant << 1) |
		(vc1->vstransform);

	pPicParams->bPicOverflowBlocks = (vc1->quantizer_mode << 6) | (vc1->multires << 5) |
		(vc1->s.resync_marker << 4) | (vc1->rangered << 3) |
		(vc1->s.max_b_frames);

	pPicParams->bPicDeblockConfined = (vc1->postprocflag << 7) | (vc1->broadcast << 6) |
		(vc1->interlace << 5) | (vc1->tfcntrflag << 4) |
		(vc1->finterpflag << 3) |
		(vc1->psf << 1) | vc1->extended_dmv;

	pPicParams->bPicStructure = *nFieldType;
	pPicParams->bPicExtrapolation = (*nFieldType == PICT_FRAME) ? 1 : 2;
	pPicParams->wBitstreamPCEelements = vc1->lumshift;
	pPicParams->wBitstreamFcodes = vc1->lumscale;
	*nSliceType = vc1->s.pict_type;

	pPicParams->bMVprecisionAndChromaRelation = ((vc1->mv_mode == MV_PMODE_1MV_HPEL_BILIN) << 3) |
		(1 << 2) |
		(0 << 1) |
		(0);

	pPicParams->bRcontrol = vc1->rnd;

	return S_OK;
}

HRESULT FFVC1ReadPictureContext(DxvaVc1PictureContext* pContext, struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize)
{
	HRESULT hr;

	if (!pContext || !pAVCtx) {
		return E_POINTER;
	}

	hr = FFVC1UpdatePictureParam(&pContext->pictureParams, pAVCtx, &pContext->fieldType, &pContext->sliceType, pBuffer, nSize);
	if (FAILED(hr)) {
		return hr;
	}

	pContext->frameSkipped = FFIsSkipped(pAVCtx) ? TRUE : FALSE;
	return S_OK;
}

int FFIsSkipped(struct AVCodecContext* pAVCtx)
{
	VC1Context* vc1 = (VC1Context*)pAVCtx->priv_data;
	return vc1->p_frame_skipped;
}

int FFVC1IsInterlaced(struct AVCodecContext* pAVCtx)
{
	VC1Context* vc1 = (VC1Context*)pAVCtx->priv_data;
	return vc1->interlace;
}

/* RFC-0047 phase 4c-ii: read extradata from AVCodecContext without avcodec.h in session TU. */
void FFVC1ReadAvctxExtradata(struct AVCodecContext* pAVCtx, const uint8_t** ppData, int* pSize)
{
	if (ppData) {
		*ppData = NULL;
	}
	if (pSize) {
		*pSize = 0;
	}
	if (!pAVCtx || !ppData || !pSize) {
		return;
	}
	if (pAVCtx->extradata && pAVCtx->extradata_size > 0) {
		*ppData = pAVCtx->extradata;
		*pSize = pAVCtx->extradata_size;
	}
}
