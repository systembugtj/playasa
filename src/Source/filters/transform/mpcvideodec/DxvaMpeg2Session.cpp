#include "stdafx.h"

#include <cstdlib>
#include <cstring>
#include <vector>

#include "DxvaCodecContext.h"
#include "FfmpegContext.h"
#include "modern_ffmpeg/ModernFfmpegDxvaMpeg2BridgeConsumer.h"

// RFC-0047 phase 4c-ii: MPEG-2 DXVA session routes to modern island parse when bridge DLL is available.
struct DxvaMpeg2DxvaSession {
	AVCodecContext* avctx;
	std::vector<uint8_t> extradata;
	bool use_modern;
	PlayasaDxvaMpeg2ParseSession* modern_session;
};

static void DxvaMpeg2SessionCacheExtradata(DxvaMpeg2DxvaSession* session, const uint8_t* data, size_t size)
{
	if (!session) {
		return;
	}

	session->extradata.clear();
	if (data && size > 0) {
		session->extradata.assign(data, data + size);
	}
}

static void DxvaMpeg2SessionSeedFromAvctx(DxvaMpeg2DxvaSession* session)
{
	const uint8_t* extraData = NULL;
	int extraDataSize = 0;

	if (!session || !session->avctx) {
		return;
	}

	FFMpeg2ReadAvctxExtradata(session->avctx, &extraData, &extraDataSize);
	if (extraData && extraDataSize > 0) {
		DxvaMpeg2SessionCacheExtradata(session, extraData, static_cast<size_t>(extraDataSize));
	}
}

static void DxvaMpeg2SessionTryOpenModern(DxvaMpeg2DxvaSession* session)
{
	if (!session || !session->use_modern || !session->modern_session) {
		return;
	}

	ModernFfmpegDxvaMpeg2Bridge::Consumer& bridge = ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance();
	const uint8_t* extraData = session->extradata.empty() ? NULL : &session->extradata[0];
	const size_t extraDataSize = session->extradata.size();

	if (!bridge.Open(session->modern_session, extraData, extraDataSize)) {
		session->use_modern = false;
	}
}

static void DxvaMpeg2SessionApplyOutput(const PlayasaDxvaMpeg2ParseOutput& output, DxvaMpeg2PictureContext* context)
{
	if (!context) {
		return;
	}

	const DXVA_PictureParameters layout = context->pictureParams;

	context->pictureParams = output.picture_params;
	context->qmatrixData = output.qmatrix_data;
	memcpy(context->sliceInfo, output.slice_info, sizeof(DXVA_SliceInfo) * output.slice_count);
	context->sliceCount = output.slice_count;
	context->fieldType = output.field_type;
	context->sliceType = output.slice_type;
	context->codedPictureNumber = output.coded_picture_number;
	context->alternateScan = output.alternate_scan ? TRUE : FALSE;
	context->nextCodecIndex = output.next_codec_index;

	/* Restore static layout from SetExtraData; decoder TU sets ref indices separately. */
	context->pictureParams.wPicWidthInMBminus1 = layout.wPicWidthInMBminus1;
	context->pictureParams.wPicHeightInMBminus1 = layout.wPicHeightInMBminus1;
}

extern "C" {

int FFMpeg2IsModernDxvaParseAvailable(void)
{
	return ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance().IsAvailable() ? 1 : 0;
}

DxvaMpeg2DxvaSession* FFMpeg2CreateDxvaSession(struct AVCodecContext* pAVCtx)
{
	DxvaMpeg2DxvaSession* session = NULL;
	const bool modernAvailable = ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance().IsAvailable();

	if (!pAVCtx && !modernAvailable) {
		return NULL;
	}

	session = (DxvaMpeg2DxvaSession*)calloc(1, sizeof(DxvaMpeg2DxvaSession));
	if (!session) {
		return NULL;
	}

	session->avctx = pAVCtx;
	session->use_modern = false;
	session->modern_session = NULL;
	DxvaMpeg2SessionSeedFromAvctx(session);

	if (modernAvailable && ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance().Create(&session->modern_session) && session->modern_session) {
		session->use_modern = true;
		DxvaMpeg2SessionTryOpenModern(session);
	}

	if (!session->use_modern && !session->avctx) {
		FFMpeg2DestroyDxvaSession(session);
		return NULL;
	}

	return session;
}

void FFMpeg2DestroyDxvaSession(DxvaMpeg2DxvaSession* pSession)
{
	if (!pSession) {
		return;
	}

	if (pSession->modern_session) {
		ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance().Destroy(pSession->modern_session);
		pSession->modern_session = NULL;
	}

	pSession->extradata.clear();
	free(pSession);
}

HRESULT FFMpeg2ReadPictureContextSession(
	DxvaMpeg2DxvaSession* pSession,
	DxvaMpeg2PictureContext* pContext,
	struct AVFrame* pFrame,
	BYTE* pBuffer,
	UINT nSize)
{
	if (!pSession || !pContext) {
		return E_POINTER;
	}

	if (pSession->use_modern && pSession->modern_session) {
		PlayasaDxvaMpeg2ParseOutput output;
		memset(&output, 0, sizeof(output));

		if (!pBuffer || nSize == 0) {
			return E_INVALIDARG;
		}

		if (!ModernFfmpegDxvaMpeg2Bridge::Consumer::Instance().ParseBuffer(pSession->modern_session, pBuffer, nSize, &output)) {
			return E_FAIL;
		}

		DxvaMpeg2SessionApplyOutput(output, pContext);
		return S_OK;
	}

	if (!pSession->avctx) {
		return E_FAIL;
	}

	return FFMpeg2ReadPictureContext(pContext, pSession->avctx, pFrame, pBuffer, nSize);
}

void FFMpeg2ApplyExtradataSession(DxvaMpeg2DxvaSession* pSession, BYTE* pDataIn, UINT nSize)
{
	if (!pSession) {
		return;
	}

	DxvaMpeg2SessionCacheExtradata(pSession, pDataIn, nSize);
	DxvaMpeg2SessionTryOpenModern(pSession);

	if (pSession->use_modern && pSession->modern_session) {
		return;
	}

	if (!pSession->avctx) {
		return;
	}

	/* Legacy path: extradata already lives on AVCodecContext from filter connect. */
}

} // extern "C"
