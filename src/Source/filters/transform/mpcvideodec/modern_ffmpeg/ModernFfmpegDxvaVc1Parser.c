#define PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_dxva_vc1.h"

#include "libavcodec/avcodec.h"
#include "libavutil/mem.h"
#include "libavcodec/mpegutils.h"
#include "libavcodec/vc1.h"
#include "libavcodec/vc1_common.h"

#include <string.h>

typedef struct DxvaVc1ParseSession {
	AVCodecContext* avctx;
	AVPacket* packet;
	AVFrame* frame;
} DxvaVc1ParseSession;

static int BuildVc1PictureParams(const VC1Context* vc1, DXVA_PictureParameters* picParams, int* fieldType, int* sliceType)
{
	if (!vc1 || !picParams || !fieldType || !sliceType) {
		return 0;
	}

	if (vc1->fcm == 0) {
		*fieldType = PICT_FRAME;
	} else {
		*fieldType = vc1->tff ? PICT_TOP_FIELD : PICT_BOTTOM_FIELD;
	}

	picParams->bPicIntra = (vc1->s.pict_type == AV_PICTURE_TYPE_I);
	picParams->bPicBackwardPrediction = (vc1->s.pict_type == AV_PICTURE_TYPE_B);

	picParams->bBidirectionalAveragingMode = (picParams->bBidirectionalAveragingMode & 0xE0) |
		((vc1->lumshift != 0 || vc1->lumscale != 32) ? 0x10 : 0) |
		((vc1->profile == PROFILE_ADVANCED) << 3);

	picParams->bPicSpatialResid8 = (vc1->panscanflag << 7) | (vc1->refdist_flag << 6) |
		(vc1->loop_filter << 5) | (vc1->fastuvmc << 4) |
		(vc1->extended_mv << 3) | (vc1->dquant << 1) |
		(vc1->vstransform);

	picParams->bPicOverflowBlocks = (vc1->quantizer_mode << 6) | (vc1->multires << 5) |
		(vc1->resync_marker << 4) | (vc1->rangered << 3) |
		(vc1->max_b_frames);

	picParams->bPicDeblockConfined = (vc1->postprocflag << 7) | (vc1->broadcast << 6) |
		(vc1->interlace << 5) | (vc1->tfcntrflag << 4) |
		(vc1->finterpflag << 3) |
		(vc1->psf << 1) | vc1->extended_dmv;

	picParams->bPicStructure = (uint8_t)*fieldType;
	picParams->bPicExtrapolation = (*fieldType == PICT_FRAME) ? 1 : 2;
	picParams->wBitstreamPCEelements = vc1->lumshift;
	picParams->wBitstreamFcodes = vc1->lumscale;
	*sliceType = vc1->s.pict_type;

	picParams->bMVprecisionAndChromaRelation = ((vc1->mv_mode == MV_PMODE_1MV_HPEL_BILIN) << 3) |
		(1 << 2) |
		(0 << 1) |
		(0);

	picParams->bRcontrol = vc1->rnd;
	return 1;
}

static int FillOutputFromContext(const DxvaVc1ParseSession* parseSession, PlayasaDxvaVc1ParseOutput* output)
{
	const VC1Context* vc1 = (const VC1Context*)parseSession->avctx->priv_data;
	if (!BuildVc1PictureParams(vc1, &output->picture_params, &output->field_type, &output->slice_type)) {
		return 0;
	}
	output->frame_skipped = vc1->p_frame_skipped ? 1 : 0;
	return 1;
}

int playasa_dxva_vc1_parse_create(PlayasaDxvaVc1ParseSession** session)
{
	DxvaVc1ParseSession* created;

	if (!session) {
		return 0;
	}

	created = (DxvaVc1ParseSession*)av_mallocz(sizeof(DxvaVc1ParseSession));
	if (!created) {
		return 0;
	}

	created->packet = av_packet_alloc();
	created->frame = av_frame_alloc();
	if (!created->packet || !created->frame) {
		playasa_dxva_vc1_parse_destroy((PlayasaDxvaVc1ParseSession*)created);
		return 0;
	}

	*session = (PlayasaDxvaVc1ParseSession*)created;
	return 1;
}

void playasa_dxva_vc1_parse_destroy(PlayasaDxvaVc1ParseSession* session)
{
	DxvaVc1ParseSession* parseSession = (DxvaVc1ParseSession*)session;
	if (!parseSession) {
		return;
	}

	if (parseSession->avctx) {
		avcodec_free_context(&parseSession->avctx);
	}
	av_packet_free(&parseSession->packet);
	av_frame_free(&parseSession->frame);
	av_free(parseSession);
}

int playasa_dxva_vc1_parse_open(
	PlayasaDxvaVc1ParseSession* session,
	const uint8_t* extra_data,
	size_t extra_data_size)
{
	DxvaVc1ParseSession* parseSession = (DxvaVc1ParseSession*)session;
	const AVCodec* codec;

	if (!parseSession) {
		return 0;
	}

	codec = avcodec_find_decoder(AV_CODEC_ID_VC1);
	if (!codec) {
		return 0;
	}

	parseSession->avctx = avcodec_alloc_context3(codec);
	if (!parseSession->avctx) {
		return 0;
	}

	parseSession->avctx->flags2 |= AV_CODEC_FLAG2_CHUNKS;

	if (extra_data && extra_data_size > 0) {
		parseSession->avctx->extradata = (uint8_t*)av_malloc(extra_data_size + AV_INPUT_BUFFER_PADDING_SIZE);
		if (!parseSession->avctx->extradata) {
			return 0;
		}
		memcpy(parseSession->avctx->extradata, extra_data, extra_data_size);
		parseSession->avctx->extradata_size = (int)extra_data_size;
	}

	return avcodec_open2(parseSession->avctx, codec, NULL) >= 0 ? 1 : 0;
}

int playasa_dxva_vc1_parse_buffer(
	PlayasaDxvaVc1ParseSession* session,
	const uint8_t* data,
	size_t data_size,
	PlayasaDxvaVc1ParseOutput* output)
{
	DxvaVc1ParseSession* parseSession = (DxvaVc1ParseSession*)session;
	int sendResult;

	if (!parseSession || !parseSession->avctx || !data || !output) {
		return 0;
	}

	av_packet_unref(parseSession->packet);
	if (av_new_packet(parseSession->packet, (int)data_size) < 0) {
		return 0;
	}
	memcpy(parseSession->packet->data, data, data_size);

	sendResult = avcodec_send_packet(parseSession->avctx, parseSession->packet);
	if (sendResult < 0 && sendResult != AVERROR(EAGAIN)) {
		return 0;
	}

	while (avcodec_receive_frame(parseSession->avctx, parseSession->frame) == 0) {
		av_frame_unref(parseSession->frame);
	}

	return FillOutputFromContext(parseSession, output);
}
