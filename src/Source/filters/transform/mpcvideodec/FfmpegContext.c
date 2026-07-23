

/* 
 * $Id: FfmpegContext.c 1233 2009-08-16 10:07:18Z casimir666 $
 *
 * (C) 2006-2007 see AUTHORS
 *
 * This file is part of mplayerc.
 *
 * Mplayerc is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Mplayerc is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#define HAVE_AV_CONFIG_H
#define H264_MERGE_TESTING

#include <windows.h>
#include <winnt.h>
#include <vfwmsgs.h>
#include "FfmpegContext.h"
#include "dsputil.h"
#include "avcodec.h"
#include "mpegvideo.h"
#include "golomb.h"

#include "vc1.h"


int av_vc1_decode_frame(AVCodecContext *avctx, uint8_t *buf, int buf_size);


const byte ZZ_SCAN[16]  =
{  0,  1,  4,  8,  5,  2,  3,  6,  9, 12, 13, 10,  7, 11, 14, 15
};

const byte ZZ_SCAN8[64] =
{  0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
   12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
   35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
   58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};


// FIXME : remove duplicate declaration with ffmpeg ??
typedef struct Mpeg1Context {
    MpegEncContext mpeg_enc_ctx;
    int mpeg_enc_ctx_allocated; /* true if decoding context allocated */
    int repeat_field; /* true if we must repeat the field */
    AVPanScan pan_scan; /** some temporary storage for the panscan */
    int slice_count;
    int swap_uv;//indicate VCR2
    int save_aspect_info;
    int save_width, save_height, save_progressive_seq;
    AVRational frame_rate_ext;       ///< MPEG-2 specific framerate modificator
    int sync;                        ///< Did we reach a sync point like a GOP/SEQ/KEYFrame?
    DXVA_SliceInfo* pSliceInfo;
} Mpeg1Context;



int IsVista()
{
	OSVERSIONINFO osver;

	osver.dwOSVersionInfoSize = sizeof( OSVERSIONINFO );
	
	if (	GetVersionEx( &osver ) && 
			osver.dwPlatformId == VER_PLATFORM_WIN32_NT && 
			(osver.dwMajorVersion >= 6 ) )
		return 1;

	return 0;
}

char* GetFFMpegPictureType(int nType)
{
	static char*	s_FFMpegPictTypes[] = { "? ", "I ", "P ", "B ", "S ", "SI", "SP" };
	int		nTypeCount = sizeof(s_FFMpegPictTypes)/sizeof(TCHAR)-1;

	return s_FFMpegPictTypes[min(nType, nTypeCount)];
}


inline MpegEncContext* GetMpegEncContext(struct AVCodecContext* pAVCtx)
{
    Mpeg1Context*		s1;
    MpegEncContext*		s = NULL;

    switch (pAVCtx->codec_id)
    {
    case CODEC_ID_VC1 :
    case CODEC_ID_H264 :
        s = (MpegEncContext*) pAVCtx->priv_data;
        break;
    case CODEC_ID_MPEG2VIDEO:
        s1 = (Mpeg1Context*)pAVCtx->priv_data;
        s  = (MpegEncContext*)&s1->mpeg_enc_ctx;
        break;
    }
    return s;
}


/* RFC-0033: fill DxvaVc1PictureContext from legacy VC1Context readers. */
HRESULT FFVC1ReadPictureContext (DxvaVc1PictureContext* pContext, struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize)
{
	HRESULT hr;

	if (!pContext || !pAVCtx)
		return E_POINTER;

	hr = FFVC1UpdatePictureParam (&pContext->pictureParams, pAVCtx, &pContext->fieldType, &pContext->sliceType, pBuffer, nSize);
	if (FAILED(hr))
		return hr;

	pContext->frameSkipped = FFIsSkipped (pAVCtx) ? TRUE : FALSE;
	return S_OK;
}

HRESULT FFMpeg2ReadPictureContext (DxvaMpeg2PictureContext* pContext, struct AVCodecContext* pAVCtx, struct AVFrame* pFrame, BYTE* pBuffer, UINT nSize)
{
    int					i;
    int					got_picture = 0;
    Mpeg1Context*		s1 = (Mpeg1Context*)pAVCtx->priv_data;
    MpegEncContext*		s  = (MpegEncContext*)&s1->mpeg_enc_ctx;

    if (pBuffer)
    {
        s1->pSliceInfo = pContext->sliceInfo;
        avcodec_decode_video (pAVCtx, pFrame, &got_picture, pBuffer, nSize);
        pContext->sliceCount = s1->slice_count;
    }

    // pictureParams.wDecodedPictureIndex;			set in DecodeFrame
    // pictureParams.wDeblockedPictureIndex;			0 for Mpeg2
    // pictureParams.wForwardRefPictureIndex;			set in DecodeFrame
    // pictureParams.wBackwardRefPictureIndex;		set in DecodeFrame

    pContext->pictureParams.wPicWidthInMBminus1				= s->mb_width-1;
    pContext->pictureParams.wPicHeightInMBminus1			= s->mb_height-1;

    pContext->pictureParams.bMacroblockWidthMinus1			= 15;	// This is equal to ?5?for MPEG-1, MPEG-2, H.263, and MPEG-4
    pContext->pictureParams.bMacroblockHeightMinus1			= 15;	// This is equal to ?5?for MPEG-1, MPEG-2, H.261, H.263, and MPEG-4

    pContext->pictureParams.bBlockWidthMinus1				= 7;	// This is equal to ??for MPEG-1, MPEG-2, H.261, H.263, and MPEG-4
    pContext->pictureParams.bBlockHeightMinus1				= 7;	// This is equal to ??for MPEG-1, MPEG-2, H.261, H.263, and MPEG-4

    pContext->pictureParams.bBPPminus1						= 7;	// It is equal to ??for MPEG-1, MPEG-2, H.261, and H.263

    pContext->pictureParams.bPicStructure					= s->picture_structure;
    //	pictureParams.bSecondField;
    pContext->pictureParams.bPicIntra						= (s->current_picture.pict_type == FF_I_TYPE);
    pContext->pictureParams.bPicBackwardPrediction			= (s->current_picture.pict_type == FF_B_TYPE);

    pContext->pictureParams.bBidirectionalAveragingMode		= 0;	// The value ??indicates MPEG-1 and MPEG-2 rounded averaging (//2), 
    // pictureParams.bMVprecisionAndChromaRelation = 0;	// Indicates that luminance motion vectors have half-sample precision and that chrominance motion vectors are derived from luminance motion vectors according to the rules in MPEG-2
    pContext->pictureParams.bChromaFormat					= 0x01;	// For MPEG-1, MPEG-2 �Main Profile,?H.261 and H.263 bitstreams, this value shall always be set to ?1? indicating "4:2:0" format

    // pictureParams.bPicScanFixed				= 1;	// set in UpdatePicParams
    // pictureParams.bPicScanMethod				= 1;	// set in UpdatePicParams
    // pictureParams.bPicReadbackRequests;				// ??

    // pictureParams.bRcontrol					= 0;	// It shall be set to ??for all MPEG-1, and MPEG-2 bitstreams in order to conform with the rounding operator defined by those standards
    // pictureParams.bPicSpatialResid8;					// set in UpdatePicParams
    // pictureParams.bPicOverflowBlocks;					// set in UpdatePicParams
    // pictureParams.bPicExtrapolation;			= 0;	// by H.263 Annex D and MPEG-4

    // pictureParams.bPicDeblocked;				= 0;	// MPEG2_A Restricted Profile
    // pictureParams.bPicDeblockConfined;					// ??
    // pictureParams.bPic4MVallowed;						// See H.263 Annexes F and J
    // pictureParams.bPicOBMC;							// H.263 Annex F
    // pictureParams.bPicBinPB;							// Annexes G and M of H.263
    // pictureParams.bMV_RPS;								// ???
    // pictureParams.bReservedBits;						// ??

    pContext->pictureParams.wBitstreamFcodes				= (s->mpeg_f_code[0][0]<<12)  | (s->mpeg_f_code[0][1]<<8) |
        (s->mpeg_f_code[1][0]<<4)   | (s->mpeg_f_code[1][1]);
    pContext->pictureParams.wBitstreamPCEelements			= (s->intra_dc_precision<<14) | (s->picture_structure<<12) |
        (s->top_field_first<<11)    | (s->frame_pred_frame_dct<<10)| 
        (s->concealment_motion_vectors<<9) | (s->q_scale_type<<8)| 
        (s->intra_vlc_format<<7)	  | (s->alternate_scan<<6)| 
        (s->repeat_first_field<<5)  | (s->chroma_420_type<<4)| 
        (s->progressive_frame<<3);

    // TODO : could be interesting to parameter concealment method?
    // pictureParams.bBitstreamConcealmentNeed;
    // pictureParams.bBitstreamConcealmentMethod;

    pContext->qmatrixData.bNewQmatrix[0] = 1;
    pContext->qmatrixData.bNewQmatrix[1] = 1;
    pContext->qmatrixData.bNewQmatrix[2] = 1;
    pContext->qmatrixData.bNewQmatrix[3] = 1;
    for (i=0; i<64; i++)	// intra Y, inter Y, intra chroma, inter chroma 
    {
        pContext->qmatrixData.Qmatrix[0][i] = s->intra_matrix[ZZ_SCAN8[i]];
        pContext->qmatrixData.Qmatrix[1][i] = s->inter_matrix[ZZ_SCAN8[i]];
        pContext->qmatrixData.Qmatrix[2][i] = s->chroma_intra_matrix[ZZ_SCAN8[i]];
        pContext->qmatrixData.Qmatrix[3][i] = s->chroma_inter_matrix[ZZ_SCAN8[i]];
    }

    if (got_picture)
        pContext->nextCodecIndex = pFrame->coded_picture_number;
    pContext->fieldType = s->picture_structure;
    pContext->sliceType = s->current_picture.pict_type;
    pContext->codedPictureNumber = s->current_picture.coded_picture_number;
    pContext->alternateScan = s->alternate_scan;

    return S_OK;
}

HRESULT FFMpeg2DecodeFrame (DXVA_PictureParameters* pPicParams, DXVA_QmatrixData* pQMatrixData, DXVA_SliceInfo* pSliceInfo, int* nSliceCount, 
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
    context.codedPictureNumber = FFGetCodedPicture(pAVCtx);
    context.alternateScan = FFGetAlternateScan(pAVCtx);

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



unsigned long FFGetMBNumber(struct AVCodecContext* pAVCtx)
{
    MpegEncContext*		s = GetMpegEncContext(pAVCtx);

    return (s != NULL) ? s->mb_num : 0;
}

int FFIsSkipped(struct AVCodecContext* pAVCtx)
{
	VC1Context*		vc1 = (VC1Context*) pAVCtx->priv_data;
	return vc1->p_frame_skipped;
}

int FFIsInterlaced(struct AVCodecContext* pAVCtx, int nHeight)
{
	if (pAVCtx->codec_id == CODEC_ID_H264)
	{
		return FFH264IsInterlaced(pAVCtx) ? 1 : 0;
	}
	else if (pAVCtx->codec_id == CODEC_ID_VC1)
	{
		VC1Context*		vc1 = (VC1Context*) pAVCtx->priv_data;
		return vc1->interlace;
	}

	return 0;
}

int FFGetCodedPicture(struct AVCodecContext* pAVCtx)
{
    MpegEncContext*		s = GetMpegEncContext(pAVCtx);

    return (s != NULL) ? s->current_picture.coded_picture_number : 0;
}

BOOL FFGetAlternateScan(struct AVCodecContext* pAVCtx)
{
    MpegEncContext*		s = GetMpegEncContext(pAVCtx);

    return (s != NULL) ? s->alternate_scan : 0;
}
