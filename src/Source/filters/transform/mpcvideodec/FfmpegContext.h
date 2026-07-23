/* 
 * $Id: FfmpegContext.h 1207 2009-08-02 15:35:14Z casimir666 $
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

#pragma once

#include <dxva.h>
#include "DxvaCodecContext.h"

struct AVCodecContext;


enum PCI_Vendors
{
    PCIV_ATI				= 0x1002,
    PCIV_nVidia				= 0x10DE,
    PCIV_Intel				= 0x8086,
    PCIV_S3_Graphics		= 0x5333
};

// Bitmasks for DXVA compatibility check
#define DXVA_UNSUPPORTED_LEVEL   1
#define DXVA_TOO_MUCH_REF_FRAMES 2
#define DXVA_INCOMPATIBLE_SAR    4

// === H264 functions
void			FFH264DecodeBuffer (struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize, int* pFramePOC, int* pOutPOC, REFERENCE_TIME* pOutrtStart);
HRESULT			FFH264BuildPicParams (DXVA_PicParams_H264* pDXVAPicParams, DXVA_Qmatrix_H264* pDXVAScalingMatrix, int* nFieldType, int* nSliceType, struct AVCodecContext* pAVCtx, int nPCIVendor);
HRESULT			FFH264ReadPictureContext (DxvaH264PictureContext* pContext, struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize, int nPCIVendor);
int				FFH264CheckCompatibility(int nWidth, int nHeight, struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize, int nPCIVendor, int m_nPCIDevice, LARGE_INTEGER VideoDriverVersion, int* refFrameCount);
void			FFH264SetCurrentPicture (int nIndex, DXVA_PicParams_H264* pDXVAPicParams, struct AVCodecContext* pAVCtx);
void			FFH264UpdateRefFramesList (DXVA_PicParams_H264* pDXVAPicParams, struct AVCodecContext* pAVCtx);
BOOL			FFH264IsRefFrameInUse (int nFrameNum, struct AVCodecContext* pAVCtx);
void			FF264UpdateRefFrameSliceLong(DXVA_PicParams_H264* pDXVAPicParams, DXVA_Slice_H264_Long* pSlice, struct AVCodecContext* pAVCtx);
void			FFH264SetDxvaSliceLong (struct AVCodecContext* pAVCtx, void* pSliceLong);
/* RFC-0047 phase 1: keep H.264 DXVA decoder TU free of avcodec.h field access. */
int				FFH264GetNalLengthSize (struct AVCodecContext* pAVCtx);
void			FFH264ApplyExtradata (struct AVCodecContext* pAVCtx, BYTE* pDataIn, UINT nSize, void* pSliceLong);
BOOL			FFH264IsInterlaced (struct AVCodecContext* pAVCtx);

/* RFC-0047 phase 2: H.264 DXVA session — decoder TU binds once, no GetAVCtx() per frame. */
DxvaH264DxvaSession*	FFH264CreateDxvaSession (struct AVCodecContext* pAVCtx);
void					FFH264DestroyDxvaSession (DxvaH264DxvaSession* pSession);
void					FFH264DecodeBufferSession (DxvaH264DxvaSession* pSession, BYTE* pBuffer, UINT nSize, DxvaH264PictureContext* pContext);
HRESULT					FFH264ReadPictureContextSession (DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, BYTE* pBuffer, UINT nSize, int nPCIVendor);
void					FFH264SetCurrentPictureSession (DxvaH264DxvaSession* pSession, int nIndex, DxvaH264PictureContext* pContext);
void					FFH264UpdateRefFramesListSession (DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext);
BOOL					FFH264IsRefFrameInUseSession (DxvaH264DxvaSession* pSession, int nFrameNum);
void					FF264UpdateRefFrameSliceLongSession (DxvaH264DxvaSession* pSession, DxvaH264PictureContext* pContext, DXVA_Slice_H264_Long* pSlice);
int						FFH264GetNalLengthSizeSession (DxvaH264DxvaSession* pSession);
void					FFH264ApplyExtradataSession (DxvaH264DxvaSession* pSession, BYTE* pDataIn, UINT nSize, void* pSliceLong);

// === VC1 functions
HRESULT			FFVC1UpdatePictureParam (DXVA_PictureParameters* pPicParams, struct AVCodecContext* pAVCtx, int* nFieldType, int* nSliceType, BYTE* pBuffer, UINT nSize);
HRESULT			FFVC1ReadPictureContext (DxvaVc1PictureContext* pContext, struct AVCodecContext* pAVCtx, BYTE* pBuffer, UINT nSize);
int				FFIsSkipped(struct AVCodecContext* pAVCtx);

// === Mpeg2 functions
HRESULT			FFMpeg2ReadPictureContext (DxvaMpeg2PictureContext* pContext, struct AVCodecContext* pAVCtx, struct AVFrame* pFrame, BYTE* pBuffer, UINT nSize);
HRESULT			FFMpeg2DecodeFrame (DXVA_PictureParameters* pPicParams, DXVA_QmatrixData* m_QMatrixData, DXVA_SliceInfo* pSliceInfo, int* nSliceCount,
struct AVCodecContext* pAVCtx, struct AVFrame* pFrame, int* nNextCodecIndex, int* nFieldType, int* nSliceType, BYTE* pBuffer, UINT nSize);

// === Common functions
int				IsVista();
char*			GetFFMpegPictureType(int nType);
int				FFIsInterlaced(struct AVCodecContext* pAVCtx, int nHeight);
unsigned long	FFGetMBNumber(struct AVCodecContext* pAVCtx);
//void			FFSetThreadNumber(struct AVCodecContext* pAVCtx, int nThreadCount);
//BOOL			FFSoftwareCheckCompatibility(struct AVCodecContext* pAVCtx);
int				FFGetCodedPicture(struct AVCodecContext* pAVCtx);
BOOL			FFGetAlternateScan(struct AVCodecContext* pAVCtx);
