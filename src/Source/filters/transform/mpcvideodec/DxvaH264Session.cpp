#include "stdafx.h"

#include <cstdlib>
#include <cstring>
#include <vector>

#include "DxvaCodecContext.h"
#include "FfmpegContext.h"
#include "h264_bitstream/H264BitstreamUtils.h"
#include "modern_ffmpeg/ModernFfmpegDxvaH264BridgeConsumer.h"

// RFC-0047 phase 3c: session routes to modern island parse when bridge DLL is available.
// RFC-0047 phase 3d: modern path does not require AVCodecContext (no avcodec.h in this TU).
struct DxvaH264DxvaSession {
	AVCodecContext* avctx;
	std::vector<uint8_t> extradata;
	int nal_length_size;
	bool use_modern;
	PlayasaDxvaH264ParseSession* modern_session;
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
	const uint8_t* extraData = NULL;
	int extraDataSize = 0;

	if (!session || !session->avctx) {
		return;
	}

	FFH264ReadAvctxExtradata(session->avctx, &extraData, &extraDataSize);
	if (extraData && extraDataSize > 0) {
		DxvaH264SessionCacheExtradata(session, extraData, static_cast<size_t>(extraDataSize));
	}
}

static void DxvaH264SessionTryOpenModern(DxvaH264DxvaSession* session)
{
	if (!session || !session->use_modern || !session->modern_session) {
		return;
	}

	ModernFfmpegDxvaBridge::Consumer& bridge = ModernFfmpegDxvaBridge::Consumer::Instance();
	const uint8_t* extraData = session->extradata.empty() ? NULL : &session->extradata[0];
	const size_t extraDataSize = session->extradata.size();
	const int32_t nalLengthSize = session->nal_length_size != PlayasaH264::kUnknownNalLengthSize ?
		session->nal_length_size : 0;

	if (!bridge.Open(session->modern_session, extraData, extraDataSize, nalLengthSize)) {
		session->use_modern = false;
	}
}

static void DxvaH264SessionApplyOutput(const PlayasaDxvaH264ParseOutput& output, DxvaH264PictureContext* context)
{
	if (!context) {
		return;
	}

	context->framePOC = output.frame_poc;
	context->outPOC = output.out_poc;
	context->outRtStart = output.out_rt_start;
	context->fieldType = output.field_type;
	context->sliceType = output.slice_type;
	context->picParams = output.pic_params;
	context->scalingMatrix = output.scaling_matrix;
	context->intraPicFlag = output.pic_params.IntraPicFlag ? TRUE : FALSE;
}

extern "C" {

int FFH264IsModernDxvaParseAvailable(void)
{
	return ModernFfmpegDxvaBridge::Consumer::Instance().IsAvailable() ? 1 : 0;
}

DxvaH264DxvaSession* FFH264CreateDxvaSession(struct AVCodecContext* pAVCtx)
{
	DxvaH264DxvaSession* session = NULL;
	const bool modernAvailable = ModernFfmpegDxvaBridge::Consumer::Instance().IsAvailable();

	if (!pAVCtx && !modernAvailable) {
		return NULL;
	}

	session = (DxvaH264DxvaSession*)calloc(1, sizeof(DxvaH264DxvaSession));
	if (!session) {
		return NULL;
	}

	session->avctx = pAVCtx;
	session->nal_length_size = PlayasaH264::kUnknownNalLengthSize;
	session->use_modern = false;
	session->modern_session = NULL;
	DxvaH264SessionSeedFromAvctx(session);

	if (modernAvailable && ModernFfmpegDxvaBridge::Consumer::Instance().Create(&session->modern_session) && session->modern_session) {
		session->use_modern = true;
		DxvaH264SessionTryOpenModern(session);
	}

	if (!session->use_modern && !session->avctx) {
		FFH264DestroyDxvaSession(session);
		return NULL;
	}

	return session;
}

void FFH264DestroyDxvaSession(DxvaH264DxvaSession* pSession)
{
	if (!pSession) {
		return;
	}

	if (pSession->modern_session) {
		ModernFfmpegDxvaBridge::Consumer::Instance().Destroy(pSession->modern_session);
		pSession->modern_session = NULL;
	}

	pSession->extradata.clear();
	free(pSession);
}

void FFH264DecodeBufferSession(DxvaH264DxvaSession* pSession, BYTE* pBuffer, UINT nSize, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	if (pSession->use_modern && pSession->modern_session && pBuffer) {
		PlayasaDxvaH264ParseOutput output;
		memset(&output, 0, sizeof(output));
		if (ModernFfmpegDxvaBridge::Consumer::Instance().ParseBuffer(pSession->modern_session, pBuffer, nSize, &output)) {
			DxvaH264SessionApplyOutput(output, pContext);
			return;
		}
	}

	if (!pSession->avctx) {
		return;
	}

	FFH264DecodeBuffer(pSession->avctx, pBuffer, nSize, &pContext->framePOC, &pContext->outPOC, (REFERENCE_TIME*)&pContext->outRtStart);
}

HRESULT FFH264ReadPictureContextSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, BYTE* pBuffer, UINT nSize, int nPCIVendor)
{
	if (!pSession) {
		return E_POINTER;
	}

	if (pSession->use_modern && pSession->modern_session) {
		PlayasaDxvaH264ParseOutput output;
		memset(&output, 0, sizeof(output));

		if (pBuffer && nSize > 0) {
			if (!ModernFfmpegDxvaBridge::Consumer::Instance().ParseBuffer(pSession->modern_session, pBuffer, nSize, &output)) {
				return E_FAIL;
			}
		} else if (!ModernFfmpegDxvaBridge::Consumer::Instance().FillPictureContext(pSession->modern_session, nPCIVendor, &output)) {
			return E_FAIL;
		}

		DxvaH264SessionApplyOutput(output, pContext);
		return S_OK;
	}

	if (!pSession->avctx) {
		return E_FAIL;
	}

	return FFH264ReadPictureContext(pContext, pSession->avctx, pBuffer, nSize, nPCIVendor);
}

void FFH264SetCurrentPictureSession(DxvaH264DxvaSession* pSession, int nIndex, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	if (pSession->use_modern && pSession->modern_session) {
		ModernFfmpegDxvaBridge::Consumer::Instance().SetSurfaceIndex(pSession->modern_session, nIndex);
		return;
	}

	if (!pSession->avctx) {
		return;
	}

	FFH264SetCurrentPicture(nIndex, &pContext->picParams, pSession->avctx);
}

void FFH264UpdateRefFramesListSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext)
{
	if (!pSession || !pContext) {
		return;
	}

	if (pSession->use_modern && pSession->modern_session) {
		ModernFfmpegDxvaBridge::Consumer::Instance().UpdateRefFrames(pSession->modern_session, &pContext->picParams);
		return;
	}

	if (!pSession->avctx) {
		return;
	}

	FFH264UpdateRefFramesList(&pContext->picParams, pSession->avctx);
}

BOOL FFH264IsRefFrameInUseSession(DxvaH264DxvaSession* pSession, int nFrameNum)
{
	if (!pSession) {
		return FALSE;
	}

	if (pSession->use_modern && pSession->modern_session) {
		return ModernFfmpegDxvaBridge::Consumer::Instance().IsRefInUse(pSession->modern_session, nFrameNum) ? TRUE : FALSE;
	}

	if (!pSession->avctx) {
		return FALSE;
	}

	return FFH264IsRefFrameInUse(nFrameNum, pSession->avctx);
}

void FF264UpdateRefFrameSliceLongSession(DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, DXVA_Slice_H264_Long* pSlice)
{
	if (!pSession || !pContext || !pSlice) {
		return;
	}

	if (pSession->use_modern && pSession->modern_session) {
		ModernFfmpegDxvaBridge::Consumer::Instance().UpdateSliceLong(pSession->modern_session, &pContext->picParams, pSlice);
		return;
	}

	if (!pSession->avctx) {
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

	if (!pSession->avctx) {
		return 0;
	}

	return FFH264GetNalLengthSize(pSession->avctx);
}

void FFH264ApplyExtradataSession(DxvaH264DxvaSession* pSession, BYTE* pDataIn, UINT nSize, void* pSliceLong)
{
	if (!pSession) {
		return;
	}

	DxvaH264SessionCacheExtradata(pSession, pDataIn, nSize);
	DxvaH264SessionTryOpenModern(pSession);

	if (pSession->use_modern && pSession->modern_session) {
		return;
	}

	if (!pSession->avctx) {
		return;
	}

	FFH264ApplyExtradata(pSession->avctx, pDataIn, nSize, pSliceLong);
}

} // extern "C"
