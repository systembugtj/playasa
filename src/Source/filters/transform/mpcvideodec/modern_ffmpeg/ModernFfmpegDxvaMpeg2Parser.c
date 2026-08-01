#define PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS

#include "../../../../../Thirdparty/pkg/ffmpeg_modern_dxva_mpeg2.h"

#include "libavcodec/avcodec.h"
#include "libavutil/mem.h"
#include "libavcodec/get_bits.h"
#include "libavcodec/mpegutils.h"
#include "libavcodec/mpegvideodec.h"
#include "libavcodec/mpegvideo.h"
#include "libavcodec/mpegpicture.h"

#include <string.h>

typedef struct DxvaMpeg2ParseSession {
	AVCodecContext* avctx;
	AVPacket* packet;
	AVFrame* frame;
} DxvaMpeg2ParseSession;

static const uint8_t kZzScan8[64] = {
	0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
	12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};

static int DxvaMpeg2GetBuffer2(AVCodecContext* avctx, AVFrame* frame, int flags)
{
	(void)flags;
	frame->format = AV_PIX_FMT_YUV420P;
	if (!avctx->width || !avctx->height) {
		return AVERROR(EINVAL);
	}
	return av_frame_get_buffer(frame, 32);
}

static const MpegEncContext* GetMpegEncContext(const AVCodecContext* avctx)
{
	return (const MpegEncContext*)avctx->priv_data;
}

static int FillPictureParameters(const MpegEncContext* s, DXVA_PictureParameters* picParams)
{
	if (!s || !picParams) {
		return 0;
	}

	memset(picParams, 0, sizeof(*picParams));
	picParams->wPicWidthInMBminus1 = s->mb_width - 1;
	picParams->wPicHeightInMBminus1 = s->mb_height - 1;
	picParams->bMacroblockWidthMinus1 = 15;
	picParams->bMacroblockHeightMinus1 = 15;
	picParams->bBlockWidthMinus1 = 7;
	picParams->bBlockHeightMinus1 = 7;
	picParams->bBPPminus1 = 7;
	picParams->bPicStructure = (uint8_t)s->picture_structure;
	picParams->bPicIntra = (s->pict_type == AV_PICTURE_TYPE_I);
	picParams->bPicBackwardPrediction = (s->pict_type == AV_PICTURE_TYPE_B);
	picParams->bBidirectionalAveragingMode = 0;
	picParams->bChromaFormat = 0x01;
	picParams->wBitstreamFcodes = (uint16_t)((s->mpeg_f_code[0][0] << 12) | (s->mpeg_f_code[0][1] << 8) |
		(s->mpeg_f_code[1][0] << 4) | (s->mpeg_f_code[1][1]));
	picParams->wBitstreamPCEelements = (uint16_t)((s->intra_dc_precision << 14) | (s->picture_structure << 12) |
		(s->top_field_first << 11) | (s->frame_pred_frame_dct << 10) |
		(s->concealment_motion_vectors << 9) | (s->q_scale_type << 8) |
		(s->intra_vlc_format << 7) | (s->alternate_scan << 6) |
		(s->repeat_first_field << 5) | (s->chroma_420_type << 4) |
		(s->progressive_frame << 3));
	return 1;
}

static int FillQuantizationMatrices(const MpegEncContext* s, DXVA_QmatrixData* qmatrixData)
{
	int i;

	if (!s || !qmatrixData) {
		return 0;
	}

	memset(qmatrixData, 0, sizeof(*qmatrixData));
	qmatrixData->bNewQmatrix[0] = 1;
	qmatrixData->bNewQmatrix[1] = 1;
	qmatrixData->bNewQmatrix[2] = 1;
	qmatrixData->bNewQmatrix[3] = 1;
	for (i = 0; i < 64; i++) {
		qmatrixData->Qmatrix[0][i] = s->intra_matrix[kZzScan8[i]];
		qmatrixData->Qmatrix[1][i] = s->inter_matrix[kZzScan8[i]];
		qmatrixData->Qmatrix[2][i] = s->chroma_intra_matrix[kZzScan8[i]];
		qmatrixData->Qmatrix[3][i] = s->chroma_inter_matrix[kZzScan8[i]];
	}
	return 1;
}

static int FillSliceFromBuffer(
	const MpegEncContext* s,
	DXVA_SliceInfo* slice,
	unsigned position,
	const uint8_t* buffer,
	unsigned size)
{
	const int isField = s->picture_structure != PICT_FRAME;
	GetBitContext gb;
	int mbY;

	if (!slice || size < 4) {
		return 0;
	}

	mbY = buffer[3] - 1;
	memset(slice, 0, sizeof(*slice));
	slice->wHorizontalPosition = 0;
	slice->wVerticalPosition = (uint16_t)(mbY >> isField);
	slice->dwSliceBitsInBuffer = 8U * size;
	slice->dwSliceDataLocation = position;
	slice->bStartCodeBitOffset = 0;
	slice->wNumberMBsInSlice = (uint16_t)((mbY >> isField) * s->mb_width);
	slice->wBadSliceChopping = 0;

	init_get_bits(&gb, &buffer[4], (int)(8U * (size - 4)));
	slice->wQuantizerScaleCode = (uint16_t)get_bits(&gb, 5);
	skip_1stop_8data_bits(&gb);
	slice->wMBbitOffset = (uint16_t)(32 + get_bits_count(&gb));
	return 1;
}

static int BuildSliceTable(
	const MpegEncContext* s,
	const uint8_t* data,
	size_t dataSize,
	DXVA_SliceInfo* slices,
	int maxSlices,
	int* sliceCount)
{
	unsigned i = 0;
	int count = 0;
	unsigned slicePositions[PLAYASA_DXVA_MPEG2_MAX_SLICES];

	if (!s || !data || !slices || !sliceCount || maxSlices <= 0) {
		return 0;
	}

	while (i + 4 <= dataSize && count < maxSlices) {
		if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1) {
			const uint8_t code = data[i + 3];
			if (code >= 0x01 && code <= 0xAF) {
				slicePositions[count] = i;
				count++;
			}
		}
		i++;
	}

	if (count <= 0) {
		*sliceCount = 0;
		return 1;
	}

	for (i = 0; i < (unsigned)count; i++) {
		const unsigned position = slicePositions[i];
		const unsigned size = (i + 1 < (unsigned)count) ?
			(slicePositions[i + 1] - position) :
			((unsigned)dataSize - position);
		if (!FillSliceFromBuffer(s, &slices[i], position, &data[position], size)) {
			return 0;
		}
	}

	{
		const unsigned mbCount = (unsigned)s->mb_width * (unsigned)(s->mb_height >> (s->picture_structure != PICT_FRAME));
		unsigned iSlice;
		for (iSlice = 0; iSlice < (unsigned)count - 1; iSlice++) {
			slices[iSlice].wNumberMBsInSlice =
				(uint16_t)(slices[iSlice + 1].wNumberMBsInSlice - slices[iSlice].wNumberMBsInSlice);
		}
		slices[count - 1].wNumberMBsInSlice =
			(uint16_t)(mbCount - slices[count - 1].wNumberMBsInSlice);
	}

	*sliceCount = count;
	return 1;
}

static int FillOutputFromContext(
	const DxvaMpeg2ParseSession* parseSession,
	const uint8_t* data,
	size_t dataSize,
	PlayasaDxvaMpeg2ParseOutput* output)
{
	const MpegEncContext* s = GetMpegEncContext(parseSession->avctx);

	if (!FillPictureParameters(s, &output->picture_params)) {
		return 0;
	}
	if (!FillQuantizationMatrices(s, &output->qmatrix_data)) {
		return 0;
	}
	if (!BuildSliceTable(s, data, dataSize, output->slice_info, PLAYASA_DXVA_MPEG2_MAX_SLICES, &output->slice_count)) {
		return 0;
	}

	output->field_type = s->picture_structure;
	output->slice_type = s->pict_type;
	output->coded_picture_number = s->cur_pic.ptr ? s->cur_pic.ptr->coded_picture_number : 0;
	output->alternate_scan = s->alternate_scan;
	output->next_codec_index = output->coded_picture_number;
	return 1;
}

int playasa_dxva_mpeg2_parse_create(PlayasaDxvaMpeg2ParseSession** session)
{
	DxvaMpeg2ParseSession* created;

	if (!session) {
		return 0;
	}

	created = (DxvaMpeg2ParseSession*)av_mallocz(sizeof(DxvaMpeg2ParseSession));
	if (!created) {
		return 0;
	}

	created->packet = av_packet_alloc();
	created->frame = av_frame_alloc();
	if (!created->packet || !created->frame) {
		playasa_dxva_mpeg2_parse_destroy((PlayasaDxvaMpeg2ParseSession*)created);
		return 0;
	}

	*session = (PlayasaDxvaMpeg2ParseSession*)created;
	return 1;
}

void playasa_dxva_mpeg2_parse_destroy(PlayasaDxvaMpeg2ParseSession* session)
{
	DxvaMpeg2ParseSession* parseSession = (DxvaMpeg2ParseSession*)session;
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

int playasa_dxva_mpeg2_parse_open(
	PlayasaDxvaMpeg2ParseSession* session,
	const uint8_t* extra_data,
	size_t extra_data_size)
{
	DxvaMpeg2ParseSession* parseSession = (DxvaMpeg2ParseSession*)session;
	const AVCodec* codec;

	if (!parseSession) {
		return 0;
	}

	codec = avcodec_find_decoder(AV_CODEC_ID_MPEG2VIDEO);
	if (!codec) {
		return 0;
	}

	parseSession->avctx = avcodec_alloc_context3(codec);
	if (!parseSession->avctx) {
		return 0;
	}

	parseSession->avctx->get_buffer2 = DxvaMpeg2GetBuffer2;
	parseSession->avctx->thread_count = 1;
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

int playasa_dxva_mpeg2_parse_buffer(
	PlayasaDxvaMpeg2ParseSession* session,
	const uint8_t* data,
	size_t data_size,
	PlayasaDxvaMpeg2ParseOutput* output)
{
	DxvaMpeg2ParseSession* parseSession = (DxvaMpeg2ParseSession*)session;
	int sendResult;
	int gotFrame = 0;

	if (!parseSession || !parseSession->avctx || !data || !output) {
		return 0;
	}

	memset(output, 0, sizeof(*output));

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
		gotFrame = 1;
	}

	{
		const MpegEncContext* s = GetMpegEncContext(parseSession->avctx);
		if (!s->mb_width || !s->mb_height) {
			if (gotFrame) {
				av_frame_unref(parseSession->frame);
			}
			return 0;
		}
	}

	if (!FillOutputFromContext(parseSession, data, data_size, output)) {
		if (gotFrame) {
			av_frame_unref(parseSession->frame);
		}
		return 0;
	}

	if (gotFrame) {
		av_frame_unref(parseSession->frame);
	}
	return 1;
}
