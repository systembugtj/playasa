#pragma once

// RFC-0047: portable DXVA layouts for the modern bridge (MinGW) ABI.
// Must remain layout-compatible with Windows SDK <dxva.h> used by MPCVideoDec.

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PLAYASA_DXVA_PictureParameters {
	uint16_t wDecodedPictureIndex;
	uint16_t wDeblockedPictureIndex;
	uint16_t wForwardRefPictureIndex;
	uint16_t wBackwardRefPictureIndex;
	uint16_t wPicWidthInMBminus1;
	uint16_t wPicHeightInMBminus1;
	uint8_t bMacroblockWidthMinus1;
	uint8_t bMacroblockHeightMinus1;
	uint8_t bBlockWidthMinus1;
	uint8_t bBlockHeightMinus1;
	uint8_t bBPPminus1;
	uint8_t bPicStructure;
	uint8_t bSecondField;
	uint8_t bPicIntra;
	uint8_t bPicBackwardPrediction;
	uint8_t bBidirectionalAveragingMode;
	uint8_t bMVprecisionAndChromaRelation;
	uint8_t bChromaFormat;
	uint8_t bPicScanFixed;
	uint8_t bPicScanMethod;
	uint8_t bPicReadbackRequests;
	uint8_t bRcontrol;
	uint8_t bPicSpatialResid8;
	uint8_t bPicOverflowBlocks;
	uint8_t bPicExtrapolation;
	uint8_t bPicDeblocked;
	uint8_t bPicDeblockConfined;
	uint8_t bPic4MVallowed;
	uint8_t bPicOBMC;
	uint8_t bPicBinPB;
	uint8_t bMV_RPS;
	uint8_t bReservedBits;
	uint16_t wBitstreamFcodes;
	uint16_t wBitstreamPCEelements;
	uint8_t bBitstreamConcealmentNeed;
	uint8_t bBitstreamConcealmentMethod;
} DXVA_PictureParameters;

typedef struct PLAYASA_DXVA_PicEntry_H264 {
	union {
		struct {
			uint8_t Index7Bits : 7;
			uint8_t AssociatedFlag : 1;
		};
		uint8_t bPicEntry;
	};
} DXVA_PicEntry_H264;

typedef struct PLAYASA_DXVA_PicParams_H264 {
	uint16_t wFrameWidthInMbsMinus1;
	uint16_t wFrameHeightInMbsMinus1;
	DXVA_PicEntry_H264 CurrPic;
	uint8_t num_ref_frames;
	union {
		struct {
			uint16_t field_pic_flag : 1;
			uint16_t MbaffFrameFlag : 1;
			uint16_t residual_colour_transform_flag : 1;
			uint16_t sp_for_switch_flag : 1;
			uint16_t chroma_format_idc : 2;
			uint16_t RefPicFlag : 1;
			uint16_t constrained_intra_pred_flag : 1;
			uint16_t weighted_pred_flag : 1;
			uint16_t weighted_bipred_idc : 2;
			uint16_t MbsConsecutiveFlag : 1;
			uint16_t frame_mbs_only_flag : 1;
			uint16_t transform_8x8_mode_flag : 1;
			uint16_t MinLumaBipredSize8x8Flag : 1;
			uint16_t IntraPicFlag : 1;
		};
		uint16_t wBitFields;
	};
	uint8_t bit_depth_luma_minus8;
	uint8_t bit_depth_chroma_minus8;
	uint16_t Reserved16Bits;
	uint32_t StatusReportFeedbackNumber;
	DXVA_PicEntry_H264 RefFrameList[16];
	int32_t CurrFieldOrderCnt[2];
	int32_t FieldOrderCntList[16][2];
	int8_t pic_init_qs_minus26;
	int8_t chroma_qp_index_offset;
	int8_t second_chroma_qp_index_offset;
	uint8_t ContinuationFlag;
	int8_t pic_init_qp_minus26;
	uint8_t num_ref_idx_l0_active_minus1;
	uint8_t num_ref_idx_l1_active_minus1;
	uint8_t Reserved8BitsA;
	uint16_t FrameNumList[16];
	uint32_t UsedForReferenceFlags;
	uint16_t NonExistingFrameFlags;
	uint16_t frame_num;
	uint8_t log2_max_frame_num_minus4;
	uint8_t pic_order_cnt_type;
	uint8_t log2_max_pic_order_cnt_lsb_minus4;
	uint8_t delta_pic_order_always_zero_flag;
	uint8_t direct_8x8_inference_flag;
	uint8_t entropy_coding_mode_flag;
	uint8_t pic_order_present_flag;
	uint8_t num_slice_groups_minus1;
	uint8_t slice_group_map_type;
	uint8_t deblocking_filter_control_present_flag;
	uint8_t redundant_pic_cnt_present_flag;
	uint8_t Reserved8BitsB;
	uint16_t slice_group_change_rate_minus1;
	uint8_t SliceGroupMap[810];
} DXVA_PicParams_H264;

typedef struct PLAYASA_DXVA_Qmatrix_H264 {
	uint8_t bScalingLists4x4[6][16];
	uint8_t bScalingLists8x8[2][64];
} DXVA_Qmatrix_H264;

typedef struct PLAYASA_DXVA_Slice_H264_Long {
	uint32_t BSNALunitDataLocation;
	uint32_t SliceBytesInBuffer;
	uint16_t wBadSliceChopping;
	uint16_t first_mb_in_slice;
	uint16_t NumMbsForSlice;
	uint16_t BitOffsetToSliceData;
	uint8_t slice_type;
	uint8_t luma_log2_weight_denom;
	uint8_t chroma_log2_weight_denom;
	uint8_t num_ref_idx_l0_active_minus1;
	uint8_t num_ref_idx_l1_active_minus1;
	int8_t slice_alpha_c0_offset_div2;
	int8_t slice_beta_offset_div2;
	uint8_t Reserved8Bits;
	DXVA_PicEntry_H264 RefPicList[2][32];
	int16_t Weights[2][32][3][2];
	int8_t slice_qs_delta;
	int8_t slice_qp_delta;
	uint8_t redundant_pic_cnt;
	uint8_t direct_spatial_mv_pred_flag;
	uint8_t cabac_init_idc;
	uint8_t disable_deblocking_filter_idc;
	uint16_t slice_id;
} DXVA_Slice_H264_Long;

#ifdef __cplusplus
}
#endif
