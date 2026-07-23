#include "stdafx.h"

#include <vector>

#include "DxvaCodecContext.h"
#include "FfmpegContext.h"
#include "h264_bitstream/H264BitstreamUtils.h"

extern "C" {
#include "avcodec.h"
}

// RFC-0047 phase 3a: session owns cached extradata/nal_length_size; legacy parse stays in FfmpegContext.c.
struct DxvaH264DxvaSession {
	AVCodecContext* avctx;
	std::vector<uint8_t> extradata;
	int nal_length_size;
};

static void DxvaH264SessionCacheExtradata(DxvaH264DxvaSession* session, const uint8_t* data, size_t size)
{
	if (!session) {
		return;
	}

	session->extradata.clear();
	if (data && size > 0) {
		session->extradata.assign(data, data + size);
		session->nal_length_size = PlayasaH264::NalLengthSizeFromExtradata(data, size);
	}
}

static void DxvaH264SessionSeedFromAvctx(DxvaH264DxvaSession* session)
{
	if (!session || !session->avctx) {
		return;
	}

	if (session->avctx->extradata && session->avctx->extradata_size > 0) {
		DxvaH264SessionCacheExtradata(
			session,
			session->avctx->extradata,
			static_cast<size_t>(session->avctx->extradata_size));
	}
}

extern "C" {

DxvaH264DxvaSession* FFH264CreateDxvaSession(struct AVCodecContext* pAVCtx)
{
	DxvaH264DxvaSession* session;

	if (!pAVCtx) {
		return NULL;
	}

	session = (DxvaH264DxvaSession*)av_mallocz(sizeof(DxvaH264DxvaSession));
	if (!session) {
		return NULL;
	}

	session->avctx = pAVCtx;
	session->nal_length_size = PlayasaH264::kUnknownNalLengthSize;
	DxvaH264SessionSeedFromAvctx(session);
	return session;
}

void FFH264DestroyDxvaSession(DxvaH264DxvaSession* pSession)
{
	if (pSession) {
		pSession->extradata.clear();
		av_free(pSession);
	}
}

void FFH264DecodeBufferSession(DxvaH264DxvaSession* pSession, BYTE* pBuffer, UINT nSize, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	FFH264DecodeBuffer(pSession->avctx, pBuffer, nSize, &pContext->framePOC, &pContext->outPOC, (REFERENCE_TIME*)&pContext->outRtStart);
}

HRESULT FFH264ReadPictureContextSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, BYTE* pBuffer, UINT nSize, int nPCIVendor)
{
	if (!pSession) {
		return E_POINTER;
	}

	return FFH264ReadPictureContext(pContext, pSession->avctx, pBuffer, nSize, nPCIVendor);
}

void FFH264SetCurrentPictureSession(DxvaH264DxvaSession* pSession, int nIndex, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	FFH264SetCurrentPicture(nIndex, &pContext->picParams, pSession->avctx);
}

void FFH264UpdateRefFramesListSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	FFH264UpdateRefFramesList(&pContext->picParams, pSession->avctx);
}

BOOL FFH264IsRefFrameInUseSession(DxvaH264DxvaSession* pSession, int nFrameNum)
{
	if (!pSession) {
		return FALSE;
	}

	return FFH264IsRefFrameInUse(nFrameNum, pSession->avctx);
}

void FF264UpdateRefFrameSliceLongSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, DXVA_Slice_H264_Long* pSlice)
{
	if (!pSession || !pContext || !pSlice) {
		return;
	}

	FF264UpdateRefFrameSliceLong(&pContext->picParams, pSlice, pSession->avctx);
}

int FFH264GetNalLengthSizeSession(DxvaH264DxvaSession* pSession)
{
	if (!pSession) {
		return 0;
	}

	if (pSession->nal_length_size != PlayasaH264::kUnknownNalLengthSize) {
		return pSession->nal_length_size;
	}

	return FFH264GetNalLengthSize(pSession->avctx);
}

void FFH264ApplyExtradataSession(DxvaH264DxvaSession* pSession, BYTE* pDataIn, UINT nSize, void* pSliceLong)
{
	if (!pSession) {
		return;
	}

	DxvaH264SessionCacheExtradata(pSession, pDataIn, nSize);
	FFH264ApplyExtradata(pSession->avctx, pDataIn, nSize, pSliceLong);
}

} // extern "C"
