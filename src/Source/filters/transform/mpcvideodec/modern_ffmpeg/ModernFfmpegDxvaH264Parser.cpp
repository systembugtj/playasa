#define PLAYASA_FFMPEG_MODERN_BRIDGE_EXPORTS

#include "ffmpeg_modern_dxva_h264.h"

#include "../h264_bitstream/H264BitstreamUtils.h"

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavutil/imgutils.h"
#include "libavutil/mem.h"
}

#include "libavcodec/h264dec.h"
#include "libavcodec/h264_ps.h"
#include "libavcodec/h264_sei.h"
#include "libavcodec/mpegutils.h"

#include <string.h>
#include <vector>

namespace {

const uint8_t kZzScan[16] = {
    0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15
};

const uint8_t kZzScan8[64] = {
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};

const UINT kUsedForReferenceFlags[] = {
    0x00000000, 0x00000001, 0x00000003, 0x00000007, 0x0000000F, 0x0000001F, 0x0000003F, 0x0000007F,
    0x000000FF, 0x000001FF, 0x000003FF, 0x000007FF, 0x00000FFF, 0x00001FFF, 0x00003FFF, 0x00007FFF,
    0x0000FFFF, 0x0001FFFF, 0x0003FFFF, 0x0007FFFF, 0x000FFFFF, 0x001FFFFF, 0x003FFFFF, 0x007FFFFF,
    0x00FFFFFF, 0x01FFFFFF, 0x03FFFFFF, 0x07FFFFFF, 0x0FFFFFFF, 0x1FFFFFFF, 0x3FFFFFFF, 0x7FFFFFFF,
    0xFFFFFFFF,
};

struct DxvaH264ParseSession {
    AVCodecContext* avctx;
    AVPacket* packet;
    AVFrame* frame;
    int outputed_poc;
    int64_t outputed_rtstart;
    int pci_vendor;
};

int DxvaH264GetBuffer2(AVCodecContext* avctx, AVFrame* frame, int flags)
{
    (void)flags;
    frame->format = AV_PIX_FMT_YUV420P;
    if (!avctx->width || !avctx->height) {
        return AVERROR(EINVAL);
    }
    return av_frame_get_buffer(frame, 32);
}

void CopyScalingMatrix(DXVA_Qmatrix_H264* dest, const uint8_t scaling4[6][16], const uint8_t scaling8[6][64], int pciVendor)
{
    if (pciVendor == 4098) {
        memcpy(dest->bScalingLists4x4, scaling4, sizeof(dest->bScalingLists4x4));
        memcpy(dest->bScalingLists8x8, scaling8, sizeof(dest->bScalingLists8x8));
        return;
    }

    for (int i = 0; i < 6; ++i) {
        for (int j = 0; j < 16; ++j) {
            dest->bScalingLists4x4[i][j] = scaling4[i][kZzScan[j]];
        }
    }
    for (int i = 0; i < 2; ++i) {
        for (int j = 0; j < 64; ++j) {
            dest->bScalingLists8x8[i][j] = scaling8[i][kZzScan8[j]];
        }
    }
}

int BuildPicParams(const H264Context* h, DXVA_PicParams_H264* picParams, DXVA_Qmatrix_H264* scalingMatrix, int* fieldType, int* sliceType, int pciVendor)
{
    const SPS* sps = h->ps.sps;
    const PPS* pps = h->ps.pps;
    if (!sps || !pps || !h->slice_ctx) {
        return 0;
    }

    const H264SliceContext* sl = &h->slice_ctx[0];
    const int field_pic_flag = h->picture_structure != PICT_FRAME;

    *fieldType = h->picture_structure;
    if (sps->pic_struct_present_flag && h->sei.picture_timing.present) {
        switch (h->sei.pic_struct) {
        case H264_SEI_PIC_STRUCT_TOP_FIELD:
        case H264_SEI_PIC_STRUCT_TOP_BOTTOM:
        case H264_SEI_PIC_STRUCT_TOP_BOTTOM_TOP:
            *fieldType = PICT_TOP_FIELD;
            break;
        case H264_SEI_PIC_STRUCT_BOTTOM_FIELD:
        case H264_SEI_PIC_STRUCT_BOTTOM_TOP:
        case H264_SEI_PIC_STRUCT_BOTTOM_TOP_BOTTOM:
            *fieldType = PICT_BOTTOM_FIELD;
            break;
        default:
            *fieldType = PICT_FRAME;
            break;
        }
    }

    *sliceType = sl->slice_type;

    if (sps->mb_width == 0 || sps->mb_height == 0) {
        return 0;
    }

    memset(picParams, 0, sizeof(*picParams));
    picParams->wFrameWidthInMbsMinus1 = sps->mb_width - 1;
    picParams->wFrameHeightInMbsMinus1 = sps->mb_height * (2 - sps->frame_mbs_only_flag) - 1;
    picParams->num_ref_frames = sps->ref_frame_count;
    picParams->field_pic_flag = field_pic_flag;
    picParams->MbaffFrameFlag = sps->mb_aff && !field_pic_flag;
    picParams->residual_colour_transform_flag = 0;
    picParams->sp_for_switch_flag = 0;
    picParams->chroma_format_idc = sps->chroma_format_idc;
    picParams->RefPicFlag = h->nal_ref_idc != 0;
    picParams->constrained_intra_pred_flag = pps->constrained_intra_pred;
    picParams->weighted_pred_flag = pps->weighted_pred;
    picParams->weighted_bipred_idc = pps->weighted_bipred_idc;
    picParams->frame_mbs_only_flag = sps->frame_mbs_only_flag;
    picParams->transform_8x8_mode_flag = pps->transform_8x8_mode;
    picParams->IntraPicFlag = sl->slice_type == AV_PICTURE_TYPE_I;
    picParams->bit_depth_luma_minus8 = sps->bit_depth_luma - 8;
    picParams->bit_depth_chroma_minus8 = sps->bit_depth_chroma - 8;
    picParams->frame_num = h->poc.frame_num;
    picParams->log2_max_frame_num_minus4 = sps->log2_max_frame_num - 4;
    picParams->pic_order_cnt_type = sps->poc_type;
    picParams->log2_max_pic_order_cnt_lsb_minus4 = sps->log2_max_poc_lsb - 4;
    picParams->delta_pic_order_always_zero_flag = sps->delta_pic_order_always_zero_flag;
    picParams->direct_8x8_inference_flag = sps->direct_8x8_inference_flag;
    picParams->entropy_coding_mode_flag = pps->cabac;
    picParams->pic_order_present_flag = pps->pic_order_present;
    picParams->num_slice_groups_minus1 = pps->slice_group_count - 1;
    picParams->slice_group_map_type = pps->mb_slice_group_map_type;
    picParams->deblocking_filter_control_present_flag = pps->deblocking_filter_parameters_present;
    picParams->redundant_pic_cnt_present_flag = pps->redundant_pic_cnt_present;
    picParams->slice_group_change_rate_minus1 = 0;
    picParams->chroma_qp_index_offset = pps->chroma_qp_index_offset[0];
    picParams->second_chroma_qp_index_offset = pps->chroma_qp_index_offset[1];
    picParams->num_ref_idx_l0_active_minus1 = pps->ref_count[0] - 1;
    picParams->num_ref_idx_l1_active_minus1 = pps->ref_count[1] - 1;
    picParams->pic_init_qp_minus26 = pps->init_qp - 26;
    picParams->pic_init_qs_minus26 = pps->init_qs - 26;

    if (field_pic_flag) {
        picParams->CurrPic.AssociatedFlag = h->picture_structure == PICT_BOTTOM_FIELD;
        if (picParams->CurrPic.AssociatedFlag) {
            picParams->CurrFieldOrderCnt[0] = 0;
            picParams->CurrFieldOrderCnt[1] = sl->poc_lsb + h->poc.poc_msb;
        } else {
            picParams->CurrFieldOrderCnt[0] = sl->poc_lsb + h->poc.poc_msb;
            picParams->CurrFieldOrderCnt[1] = 0;
        }
    } else if (h->cur_pic_ptr) {
        picParams->CurrPic.AssociatedFlag = 0;
        picParams->CurrFieldOrderCnt[0] = h->cur_pic_ptr->field_poc[0];
        picParams->CurrFieldOrderCnt[1] = h->cur_pic_ptr->field_poc[1];
    }

    CopyScalingMatrix(scalingMatrix, pps->scaling_matrix4, pps->scaling_matrix8, pciVendor);
    return 1;
}

void UpdateRefFramesList(const H264Context* h, DXVA_PicParams_H264* picParams)
{
    int useRefIndex = h->short_ref_count * 2;
    for (int i = 0; i < 16; ++i) {
        const H264Picture* pic = NULL;
        UCHAR associatedFlag = 0;
        if (i < h->short_ref_count) {
            pic = h->short_ref[h->short_ref_count - i - 1];
            associatedFlag = 0;
        } else if (i < h->short_ref_count + h->long_ref_count) {
            pic = h->long_ref[h->short_ref_count + h->long_ref_count - i - 1];
            associatedFlag = 1;
        }

        if (pic && pic->f) {
            picParams->FrameNumList[i] = pic->long_ref ? pic->pic_id : pic->frame_num;
            picParams->FieldOrderCntList[i][0] = pic->field_poc[0] != INT_MAX ? pic->field_poc[0] : 0;
            picParams->FieldOrderCntList[i][1] = pic->field_poc[1] != INT_MAX ? pic->field_poc[1] : 0;
            picParams->RefFrameList[i].AssociatedFlag = associatedFlag;
            picParams->RefFrameList[i].Index7Bits = (UCHAR)(intptr_t)pic->f->opaque;
        } else {
            picParams->FrameNumList[i] = 0;
            picParams->FieldOrderCntList[i][0] = 0;
            picParams->FieldOrderCntList[i][1] = 0;
            picParams->RefFrameList[i].AssociatedFlag = 1;
            picParams->RefFrameList[i].Index7Bits = 127;
        }
    }
    picParams->UsedForReferenceFlags = kUsedForReferenceFlags[useRefIndex];
}

} // namespace

extern "C" {

int playasa_dxva_h264_parse_create(PlayasaDxvaH264ParseSession** session)
{
    if (!session) {
        return 0;
    }

    DxvaH264ParseSession* created = (DxvaH264ParseSession*)av_mallocz(sizeof(DxvaH264ParseSession));
    if (!created) {
        return 0;
    }

    created->packet = av_packet_alloc();
    created->frame = av_frame_alloc();
    if (!created->packet || !created->frame) {
        playasa_dxva_h264_parse_destroy((PlayasaDxvaH264ParseSession*)created);
        return 0;
    }

    *session = (PlayasaDxvaH264ParseSession*)created;
    return 1;
}

void playasa_dxva_h264_parse_destroy(PlayasaDxvaH264ParseSession* session)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
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

int playasa_dxva_h264_parse_open(
    PlayasaDxvaH264ParseSession* session,
    const uint8_t* extra_data,
    size_t extra_data_size,
    int32_t nal_length_size)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
    if (!parseSession) {
        return 0;
    }

    const AVCodec* codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (!codec) {
        return 0;
    }

    parseSession->avctx = avcodec_alloc_context3(codec);
    if (!parseSession->avctx) {
        return 0;
    }

    parseSession->avctx->get_buffer2 = DxvaH264GetBuffer2;
    parseSession->avctx->flags2 |= AV_CODEC_FLAG2_CHUNKS;

    if (extra_data && extra_data_size > 0) {
        parseSession->avctx->extradata = (uint8_t*)av_malloc(extra_data_size + AV_INPUT_BUFFER_PADDING_SIZE);
        if (!parseSession->avctx->extradata) {
            return 0;
        }
        memcpy(parseSession->avctx->extradata, extra_data, extra_data_size);
        parseSession->avctx->extradata_size = (int)extra_data_size;
    }

    const int parsedNalLengthSize = PlayasaH264::NalLengthSizeFromExtradata(extra_data, extra_data_size);
    if (nal_length_size > 0) {
        parseSession->avctx->nal_length_size = nal_length_size;
    } else if (parsedNalLengthSize != PlayasaH264::kUnknownNalLengthSize) {
        parseSession->avctx->nal_length_size = parsedNalLengthSize;
    }

    return avcodec_open2(parseSession->avctx, codec, NULL) >= 0 ? 1 : 0;
}

int playasa_dxva_h264_parse_buffer(
    PlayasaDxvaH264ParseSession* session,
    const uint8_t* data,
    size_t data_size,
    PlayasaDxvaH264ParseOutput* output)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
    if (!parseSession || !parseSession->avctx || !data || !output) {
        return 0;
    }

    av_packet_unref(parseSession->packet);
    if (av_new_packet(parseSession->packet, (int)data_size) < 0) {
        return 0;
    }
    memcpy(parseSession->packet->data, data, data_size);

    const int sendResult = avcodec_send_packet(parseSession->avctx, parseSession->packet);
    if (sendResult < 0 && sendResult != AVERROR(EAGAIN)) {
        return 0;
    }

    while (avcodec_receive_frame(parseSession->avctx, parseSession->frame) == 0) {
        av_frame_unref(parseSession->frame);
    }

    const H264Context* h = (const H264Context*)parseSession->avctx->priv_data;
    if (!BuildPicParams(h, &output->pic_params, &output->scaling_matrix, &output->field_type, &output->slice_type, parseSession->pci_vendor)) {
        return 0;
    }

    if (h->cur_pic_ptr) {
        output->frame_poc = h->cur_pic_ptr->field_poc[0];
    }
    output->out_poc = parseSession->outputed_poc;
    output->out_rt_start = parseSession->outputed_rtstart;
    output->pic_params.IntraPicFlag = output->slice_type == AV_PICTURE_TYPE_I;
    return 1;
}

void playasa_dxva_h264_parse_set_surface_index(PlayasaDxvaH264ParseSession* session, int surface_index)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
    if (!parseSession || !parseSession->avctx) {
        return;
    }

    H264Context* h = (H264Context*)parseSession->avctx->priv_data;
    if (h && h->cur_pic_ptr && h->cur_pic_ptr->f) {
        h->cur_pic_ptr->f->opaque = (void*)(intptr_t)surface_index;
        h->cur_pic_ptr->f->reordered_opaque = surface_index;
    }
}

void playasa_dxva_h264_parse_update_ref_frames(PlayasaDxvaH264ParseSession* session, DXVA_PicParams_H264* pic_params)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
    if (!parseSession || !parseSession->avctx || !pic_params) {
        return;
    }

    UpdateRefFramesList((const H264Context*)parseSession->avctx->priv_data, pic_params);
}

int playasa_dxva_h264_parse_is_ref_in_use(PlayasaDxvaH264ParseSession* session, int surface_index)
{
    DxvaH264ParseSession* parseSession = (DxvaH264ParseSession*)session;
    if (!parseSession || !parseSession->avctx) {
        return 0;
    }

    const H264Context* h = (const H264Context*)parseSession->avctx->priv_data;
    for (int i = 0; i < h->short_ref_count; ++i) {
        if (h->short_ref[i] && h->short_ref[i]->f && (int)(intptr_t)h->short_ref[i]->f->opaque == surface_index) {
            return 1;
        }
    }
    for (int i = 0; i < h->long_ref_count; ++i) {
        if (h->long_ref[i] && h->long_ref[i]->f && (int)(intptr_t)h->long_ref[i]->f->opaque == surface_index) {
            return 1;
        }
    }
    return 0;
}

void playasa_dxva_h264_parse_update_slice_long(
    PlayasaDxvaH264ParseSession* session,
    DXVA_PicParams_H264* pic_params,
    DXVA_Slice_H264_Long* slice)
{
    (void)session;
    (void)pic_params;
    (void)slice;
    // TODO RFC-0047 3c: port FF264UpdateRefFrameSliceLong against modern ref_list.
}

} // extern "C"
