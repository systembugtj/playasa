#include "stdafx.h"

#include <cstdlib>
#include <cstring>
#include <vector>

#include "DxvaCodecContext.h"
#include "FfmpegContext.h"
#include "modern_ffmpeg/ModernFfmpegDxvaVc1BridgeConsumer.h"

// RFC-0047 phase 4c-ii: VC-1 DXVA session routes to modern island parse when bridge DLL is available.
struct DxvaVc1DxvaSession {
	AVCodecContext* avctx;
	std::vector<uint8_t> extradata;
	bool use_modern;
	PlayasaDxvaVc1ParseSession* modern_session;
};

static void DxvaVc1SessionCacheExtradata(DxvaVc1DxvaSession* session, const uint8_t* data, size_t size)
{
	if (!session) {
		return;
	}

	session->extradata.clear();
	if (data && size > 0) {
		session->extradata.assign(data, data + size);
	}
}

static void DxvaVc1SessionSeedFromAvctx(DxvaVc1DxvaSession* session)
{
	const uint8_t* extraData = NULL;
	int extraDataSize = 0;

	if (!session || !session->avctx) {
		return;
	}

	FFVC1ReadAvctxExtradata(session->avctx, &extraData, &extraDataSize);
	if (extraData && extraDataSize > 0) {
		DxvaVc1SessionCacheExtradata(session, extraData, static_cast<size_t>(extraDataSize));
	}
}

static void DxvaVc1SessionTryOpenModern(DxvaVc1DxvaSession* session)
{
	if (!session || !session->use_modern || !session->modern_session) {
		return;
	}

	ModernFfmpegDxvaVc1Bridge::Consumer& bridge = ModernFfmpegDxvaVc1Bridge::Consumer::Instance();
	const uint8_t* extraData = session->extradata.empty() ? NULL : &session->extradata[0];
	const size_t extraDataSize = session->extradata.size();

	if (!bridge.Open(session->modern_session, extraData, extraDataSize)) {
		session->use_modern = false;
	}
}

static void DxvaVc1SessionApplyOutput(const PlayasaDxvaVc1ParseOutput& output, DxvaVc1PictureContext* context)
{
	if (!context) {
		return;
	}

	const DXVA_PictureParameters layout = context->pictureParams;

	context->fieldType = output.field_type;
	context->sliceType = output.slice_type;
	context->frameSkipped = output.frame_skipped ? TRUE : FALSE;
	context->pictureParams = output.picture_params;

	/* Restore static layout from SetExtraData; legacy glue only updates dynamic bitstream fields. */
	context->pictureParams.wPicWidthInMBminus1 = layout.wPicWidthInMBminus1;
	context->pictureParams.wPicHeightInMBminus1 = layout.wPicHeightInMBminus1;
	context->pictureParams.bMacroblockWidthMinus1 = layout.bMacroblockWidthMinus1;
	context->pictureParams.bMacroblockHeightMinus1 = layout.bMacroblockHeightMinus1;
	context->pictureParams.bBlockWidthMinus1 = layout.bBlockWidthMinus1;
	context->pictureParams.bBlockHeightMinus1 = layout.bBlockHeightMinus1;
	context->pictureParams.bBPPminus1 = layout.bBPPminus1;
	context->pictureParams.bChromaFormat = layout.bChromaFormat;
	context->pictureParams.bPicScanFixed = layout.bPicScanFixed;
	context->pictureParams.bPicReadbackRequests = layout.bPicReadbackRequests;
	context->pictureParams.bPicDeblocked = layout.bPicDeblocked;
	context->pictureParams.bPicOBMC = layout.bPicOBMC;
	context->pictureParams.bPicBinPB = layout.bPicBinPB;
	context->pictureParams.bMV_RPS = layout.bMV_RPS;
	context->pictureParams.bReservedBits = layout.bReservedBits;
	context->pictureParams.bBidirectionalAveragingMode =
		(layout.bBidirectionalAveragingMode & 0xE0) |
		(context->pictureParams.bBidirectionalAveragingMode & 0x1F);
}

extern "C" {

int FFVC1IsModernDxvaParseAvailable(void)
{
	return ModernFfmpegDxvaVc1Bridge::Consumer::Instance().IsAvailable() ? 1 : 0;
}

DxvaVc1DxvaSession* FFVC1CreateDxvaSession(struct AVCodecContext* pAVCtx)
{
	DxvaVc1DxvaSession* session = NULL;
	const bool modernAvailable = ModernFfmpegDxvaVc1Bridge::Consumer::Instance().IsAvailable();

	if (!pAVCtx && !modernAvailable) {
		return NULL;
	}

	session = (DxvaVc1DxvaSession*)calloc(1, sizeof(DxvaVc1DxvaSession));
	if (!session) {
		return NULL;
	}

	session->avctx = pAVCtx;
	session->use_modern = false;
	session->modern_session = NULL;
	DxvaVc1SessionSeedFromAvctx(session);

	if (modernAvailable && ModernFfmpegDxvaVc1Bridge::Consumer::Instance().Create(&session->modern_session) && session->modern_session) {
		session->use_modern = true;
		DxvaVc1SessionTryOpenModern(session);
	}

	if (!session->use_modern && !session->avctx) {
		FFVC1DestroyDxvaSession(session);
		return NULL;
	}

	return session;
}

void FFVC1DestroyDxvaSession(DxvaVc1DxvaSession* pSession)
{
	if (!pSession) {
		return;
	}

	if (pSession->modern_session) {
		ModernFfmpegDxvaVc1Bridge::Consumer::Instance().Destroy(pSession->modern_session);
		pSession->modern_session = NULL;
	}

	pSession->extradata.clear();
	free(pSession);
}

HRESULT FFVC1ReadPictureContextSession(
	DxvaVc1DxvaSession* pSession,
	DxvaVc1PictureContext* pContext,
	BYTE* pBuffer,
	UINT nSize)
{
	if (!pSession || !pContext) {
		return E_POINTER;
	}

	if (pSession->use_modern && pSession->modern_session) {
		PlayasaDxvaVc1ParseOutput output;
		memset(&output, 0, sizeof(output));

		if (!pBuffer || nSize == 0) {
			return E_INVALIDARG;
		}

		if (!ModernFfmpegDxvaVc1Bridge::Consumer::Instance().ParseBuffer(pSession->modern_session, pBuffer, nSize, &output)) {
			return E_FAIL;
		}

		DxvaVc1SessionApplyOutput(output, pContext);
		return S_OK;
	}

	if (!pSession->avctx) {
		return E_FAIL;
	}

	return FFVC1ReadPictureContext(pContext, pSession->avctx, pBuffer, nSize);
}

void FFVC1ApplyExtradataSession(DxvaVc1DxvaSession* pSession, BYTE* pDataIn, UINT nSize)
{
	if (!pSession) {
		return;
	}

	DxvaVc1SessionCacheExtradata(pSession, pDataIn, nSize);
	DxvaVc1SessionTryOpenModern(pSession);

	if (pSession->use_modern && pSession->modern_session) {
		return;
	}

	if (!pSession->avctx) {
		return;
	}

	/* Legacy path: extradata already lives on AVCodecContext from filter connect. */
}

} // extern "C"
